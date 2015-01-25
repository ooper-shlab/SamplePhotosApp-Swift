//
//  AAPLAssetGridViewController.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/25.
//
//
/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:

  A view controller displaying a grid of assets.

 */

import UIKit

import Photos


extension NSIndexSet {
    func aapl_indexPathsFromIndexesWithSection(section: Int) -> [NSIndexPath] {
        var indexPaths: [NSIndexPath] = []
        indexPaths.reserveCapacity(self.count)
        self.enumerateIndexesUsingBlock {idx, stop in
            indexPaths.append(NSIndexPath(forItem: idx, inSection: section))
        }
        return indexPaths
    }
}


extension UICollectionView {
    func aapl_indexPathsForElementsInRect(rect: CGRect) -> [NSIndexPath] {
        let allLayoutAttributes = self.collectionViewLayout.layoutAttributesForElementsInRect(rect)
        if (allLayoutAttributes?.count ?? 0) == 0 {return []}
        var indexPaths: [NSIndexPath] = []
        indexPaths.reserveCapacity(allLayoutAttributes!.count)
        for layoutAttributes in allLayoutAttributes as [UICollectionViewLayoutAttributes] {
            let indexPath = layoutAttributes.indexPath
            indexPaths.append(indexPath)
        }
        return indexPaths
    }
}

@objc(AAPLAssetGridViewController)
class AssetGridViewController: UICollectionViewController, PHPhotoLibraryChangeObserver {
    var assetsFetchResults: PHFetchResult!
    var assetCollection: PHAssetCollection!
    @IBOutlet private var addButton: UIBarButtonItem!
    private var imageManager: PHCachingImageManager!
    private var previousPreheatRect: CGRect = CGRect()
    
    private final let CellReuseIdentifier = "Cell"
    private struct My {
        static var AssetGridThumbnailSize: CGSize = CGSize()
    }
    
    override func awakeFromNib() {
        self.imageManager = PHCachingImageManager()
        self.resetCachedAssets()
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let scale = UIScreen.mainScreen().scale
        let cellSize = (self.collectionViewLayout as UICollectionViewFlowLayout).itemSize
        My.AssetGridThumbnailSize = CGSizeMake(cellSize.width * scale, cellSize.height * scale)
        
        if self.assetCollection == nil || self.assetCollection.canPerformEditOperation(.AddContent) {
            self.navigationItem.rightBarButtonItem = self.addButton
        } else {
            self.navigationItem.rightBarButtonItem = nil
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.updateCachedAssets()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        let indexPath = self.collectionView!.indexPathForCell(sender as UICollectionViewCell)!
        let assetViewController = segue.destinationViewController as AssetViewController
        assetViewController.asset = self.assetsFetchResults[indexPath.item] as PHAsset
        assetViewController.assetCollection = self.assetCollection
    }
    
    //MARK: - PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(changeInstance: PHChange!) {
        // Call might come on any background queue. Re-dispatch to the main queue to handle it.
        dispatch_async(dispatch_get_main_queue()) {
            
            // check if there are changes to the assets (insertions, deletions, updates)
            let collectionChanges = changeInstance.changeDetailsForFetchResult(self.assetsFetchResults)
            if collectionChanges != nil {
                
                // get the new fetch result
                self.assetsFetchResults = collectionChanges!.fetchResultAfterChanges
                
                let collectionView = self.collectionView!
                
                if !collectionChanges!.hasIncrementalChanges || collectionChanges!.hasMoves {
                    // we need to reload all if the incremental diffs are not available
                    collectionView.reloadData()
                    
                } else {
                    // if we have incremental diffs, tell the collection view to animate insertions and deletions
                    collectionView.performBatchUpdates({
                        let removedIndexes = collectionChanges.removedIndexes
                        if (removedIndexes?.count ?? 0) != 0 {
                            collectionView.deleteItemsAtIndexPaths(removedIndexes.aapl_indexPathsFromIndexesWithSection(0))
                        }
                        let insertedIndexes = collectionChanges.insertedIndexes
                        if (insertedIndexes?.count ?? 0) != 0 {
                            collectionView.insertItemsAtIndexPaths(insertedIndexes.aapl_indexPathsFromIndexesWithSection(0))
                        }
                        let changedIndexes = collectionChanges.changedIndexes
                        if changedIndexes.count != 0 {
                            collectionView.reloadItemsAtIndexPaths(changedIndexes.aapl_indexPathsFromIndexesWithSection(0))
                        }
                        }, completion: nil)
                }
                
                self.resetCachedAssets()
            }
        }
    }
    
    //MARK: - UICollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let count = self.assetsFetchResults.count
        return count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(CellReuseIdentifier, forIndexPath: indexPath) as GridViewCell
        
        // Increment the cell's tag
        let currentTag = cell.tag + 1
        cell.tag = currentTag
        
        let asset = self.assetsFetchResults[indexPath.item] as PHAsset
        self.imageManager.requestImageForAsset(asset,
            targetSize: My.AssetGridThumbnailSize,
            contentMode: .AspectFill,
            options: nil) {
                result, info in
                
                // Only update the thumbnail if the cell tag hasn't changed. Otherwise, the cell has been re-used.
                if cell.tag == currentTag {
                    cell.thumbnailImage = result
                }
                
        }
        
        return cell
    }
    //MARK: - UIScrollViewDelegate
    
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        self.updateCachedAssets()
    }
    
    //MARK: - Asset Caching
    
    private func resetCachedAssets() {
        self.imageManager.stopCachingImagesForAllAssets()
        self.previousPreheatRect = CGRectZero
    }
    
    private func updateCachedAssets() {
        let isViewVisible = self.isViewLoaded() && self.view.window != nil
        if !isViewVisible {return}
        
        // The preheat window is twice the height of the visible rect
        var preheatRect = self.collectionView!.bounds
        preheatRect = CGRectInset(preheatRect, 0.0, -0.5 * CGRectGetHeight(preheatRect))
        
        // If scrolled by a "reasonable" amount...
        let delta = abs(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect))
        if delta > CGRectGetHeight(self.collectionView!.bounds) / 3.0 {
            
            // Compute the assets to start caching and to stop caching.
            var addedIndexPaths: [NSIndexPath] = []
            var removedIndexPaths: [NSIndexPath] = []
            
            self.computeDifferenceBetweenRect(self.previousPreheatRect, andRect: preheatRect, removedHandler: {removedRect in
                let indexPaths = self.collectionView!.aapl_indexPathsForElementsInRect(removedRect)
                removedIndexPaths += indexPaths
                }, addedHandler: {addedRect in
                    let indexPaths = self.collectionView!.aapl_indexPathsForElementsInRect(addedRect)
                    addedIndexPaths += indexPaths
            })
            
            let assetsToStartCaching = self.assetsAtIndexPaths(addedIndexPaths)
            let assetsToStopCaching = self.assetsAtIndexPaths(removedIndexPaths)
            
            self.imageManager.startCachingImagesForAssets(assetsToStartCaching,
                targetSize: My.AssetGridThumbnailSize,
                contentMode: .AspectFill,
                options: nil)
            self.imageManager.stopCachingImagesForAssets(assetsToStopCaching,
                targetSize: My.AssetGridThumbnailSize,
                contentMode: .AspectFill,
                options: nil)
            
            self.previousPreheatRect = preheatRect
        }
    }
    
    private func computeDifferenceBetweenRect(oldRect: CGRect, andRect newRect: CGRect, removedHandler: CGRect->Void, addedHandler: CGRect->Void) {
        if CGRectIntersectsRect(newRect, oldRect) {
            let oldMaxY = CGRectGetMaxY(oldRect)
            let oldMinY = CGRectGetMinY(oldRect)
            let newMaxY = CGRectGetMaxY(newRect)
            let newMinY = CGRectGetMinY(newRect)
            if newMaxY > oldMaxY {
                let rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY))
                addedHandler(rectToAdd)
            }
            if oldMinY > newMinY {
                let rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY))
                addedHandler(rectToAdd)
            }
            if newMaxY < oldMaxY {
                let rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY))
                removedHandler(rectToRemove)
            }
            if oldMinY < newMinY {
                let rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY))
                removedHandler(rectToRemove)
            }
        } else {
            addedHandler(newRect)
            removedHandler(oldRect)
        }
    }
    
    private func assetsAtIndexPaths(indexPaths: [NSIndexPath]) -> [PHAsset] {
        if indexPaths.count == 0 { return [] }
        
        var assets: [PHAsset] = []
        assets.reserveCapacity(indexPaths.count)
        for indexPath in indexPaths {
            let asset = self.assetsFetchResults[indexPath.item] as PHAsset
            assets.append(asset)
        }
        return assets
    }
    
    //MARK: - Actions
    
    @IBAction func handleAddButtonItem(sender: AnyObject) {
        // Create a random dummy image.
        let rect = rand() % 2 == 0 ? CGRectMake(0, 0, 400, 300) : CGRectMake(0, 0, 300, 400)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)
        UIColor(hue: CGFloat((rand() % 100) / 100), saturation: 1.0, brightness: 1.0, alpha: 1.0).setFill()
        UIRectFillUsingBlendMode(rect, kCGBlendModeNormal)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Add it to the photo library
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(image)
            
            if self.assetCollection != nil {
                let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(forAssetCollection: self.assetCollection)
                assetCollectionChangeRequest.addAssets([assetChangeRequest.placeholderForCreatedAsset])
            }
            }, completionHandler: {success, error in
                if !success {
                    NSLog("Error creating asset: %@", error)
                }
        })
    }
    
}