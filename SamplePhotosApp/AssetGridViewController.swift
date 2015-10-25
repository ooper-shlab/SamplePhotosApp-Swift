//
//  AAPLAssetGridViewController.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/25.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 A view controller displaying a grid of assets.
 */

import UIKit
import Photos
import PhotosUI

@objc(AAPLAssetGridViewController)
class AssetGridViewController: UICollectionViewController, PHPhotoLibraryChangeObserver {
    
    var assetsFetchResults: PHFetchResult?
    var assetCollection: PHAssetCollection?
    
    @IBOutlet private weak var addButton: UIBarButtonItem!
    private var imageManager: PHCachingImageManager?
    private var previousPreheatRect: CGRect = CGRect()
    
    
    let CellReuseIdentifier = "Cell"
    static var AssetGridThumbnailSize: CGSize = CGSize()
    
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
        
        // Determine the size of the thumbnails to request from the PHCachingImageManager
        let scale = UIScreen.mainScreen().scale
        let cellSize = (self.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
        AssetGridViewController.AssetGridThumbnailSize = CGSizeMake(cellSize.width * scale, cellSize.height * scale)
        
        // Add button to the navigation bar if the asset collection supports adding content.
        if self.assetCollection == nil || self.assetCollection!.canPerformEditOperation(.AddContent) {
            self.navigationItem.rightBarButtonItem = self.addButton
        } else {
            self.navigationItem.rightBarButtonItem = nil
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Begin caching assets in and around collection view's visible rect.
        self.updateCachedAssets()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Configure the destination AAPLAssetViewController.
        if let assetViewController = segue.destinationViewController as? AssetViewController {
            let indexPath = self.collectionView!.indexPathForCell(sender as! UICollectionViewCell)!
            assetViewController.asset = self.assetsFetchResults![indexPath.item] as? PHAsset
            assetViewController.assetCollection = self.assetCollection
        }
    }
    
    //MARK: - PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(changeInstance: PHChange) {
        // Check if there are changes to the assets we are showing.
        guard let
            assetsFetchResults = self.assetsFetchResults,
            collectionChanges = changeInstance.changeDetailsForFetchResult(assetsFetchResults)
            else {return}
        
        /*
        Change notifications may be made on a background queue. Re-dispatch to the
        main queue before acting on the change as we'll be updating the UI.
        */
        dispatch_async(dispatch_get_main_queue()) {
            // Get the new fetch result.
            self.assetsFetchResults = collectionChanges.fetchResultAfterChanges
            
            let collectionView = self.collectionView!
            
            if !collectionChanges.hasIncrementalChanges || collectionChanges.hasMoves {
                // Reload the collection view if the incremental diffs are not available
                collectionView.reloadData()
                
            } else {
                /*
                Tell the collection view to animate insertions and deletions if we
                have incremental diffs.
                */
                collectionView.performBatchUpdates({
                    if let removedIndexes = collectionChanges.removedIndexes
                        where removedIndexes.count > 0 {
                            collectionView.deleteItemsAtIndexPaths(removedIndexes.aapl_indexPathsFromIndexesWithSection(0))
                    }
                    
                    if let insertedIndexes = collectionChanges.insertedIndexes
                        where insertedIndexes.count > 0 {
                            collectionView.insertItemsAtIndexPaths(insertedIndexes.aapl_indexPathsFromIndexesWithSection(0))
                    }
                    
                    if let changedIndexes = collectionChanges.changedIndexes
                        where changedIndexes.count > 0 {
                            collectionView.reloadItemsAtIndexPaths(changedIndexes.aapl_indexPathsFromIndexesWithSection(0))
                    }
                    }, completion:  nil)
            }
            
            self.resetCachedAssets()
        }
    }
    
    //MARK: - UICollectionViewDelegate
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let cell = collectionView.cellForItemAtIndexPath(indexPath)
        if #available(iOS 9.1, *) {
            self.performSegueWithIdentifier("ShowLiveAsset", sender: cell)
        } else {
            self.performSegueWithIdentifier("ShowAsset", sender: cell)
        }
    }
    
    //MARK: - UICollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.assetsFetchResults?.count ?? 0
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let asset = self.assetsFetchResults![indexPath.item] as! PHAsset
        
        // Dequeue an AAPLGridViewCell.
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(CellReuseIdentifier, forIndexPath: indexPath) as! GridViewCell
        cell.representedAssetIdentifier = asset.localIdentifier
        
        // Add a badge to the cell if the PHAsset represents a Live Photo.
        if #available(iOS 9.1, *) {
            let hasLivePhoto = asset.mediaSubtypes.contains(.PhotoLive)
            if hasLivePhoto {
                // Add Badge Image to the cell to denote that the asset is a Live Photo.
                let badge = PHLivePhotoView.livePhotoBadgeImageWithOptions(.OverContent)
                cell.livePhotoBadgeImage = badge
            }
        }
        
        // Request an image for the asset from the PHCachingImageManager.
        self.imageManager?.requestImageForAsset(asset,
            targetSize: AssetGridViewController.AssetGridThumbnailSize,
            contentMode: PHImageContentMode.AspectFill,
            options: nil)
            {result, info in
                // Set the cell's thumbnail image if it's still showing the same asset.
                if cell.representedAssetIdentifier == asset.localIdentifier {
                    cell.thumbnailImage = result
                }
        }
        
        return cell
    }
    
    //MARK: - UIScrollViewDelegate
    
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        // Update cached assets for the new visible area.
        self.updateCachedAssets()
    }
    
    //MARK: - Asset Caching
    
    private func resetCachedAssets() {
        self.imageManager?.stopCachingImagesForAllAssets()
        self.previousPreheatRect = CGRectZero
    }
    
    private func updateCachedAssets() {
        guard self.isViewLoaded() && self.view.window != nil else {
            return
        }
        
        // The preheat window is twice the height of the visible rect.
        var preheatRect = self.collectionView!.bounds
        preheatRect = CGRectInset(preheatRect, 0.0, -0.5 * CGRectGetHeight(preheatRect))
        
        /*
        Check if the collection view is showing an area that is significantly
        different to the last preheated area.
        */
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
            
            // Update the assets the PHCachingImageManager is caching.
            self.imageManager?.startCachingImagesForAssets(assetsToStartCaching,
                targetSize: AssetGridViewController.AssetGridThumbnailSize,
                contentMode: PHImageContentMode.AspectFill,
                options: nil)
            self.imageManager?.stopCachingImagesForAssets(assetsToStopCaching,
                targetSize: AssetGridViewController.AssetGridThumbnailSize,
                contentMode: PHImageContentMode.AspectFill,
                options: nil)
            
            // Store the preheat rect to compare against in the future.
            self.previousPreheatRect = preheatRect
        }
    }
    
    private func computeDifferenceBetweenRect(oldRect: CGRect, andRect newRect: CGRect, removedHandler: (CGRect)->Void, addedHandler: (CGRect)->Void) {
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
        
        let assets = indexPaths.map{self.assetsFetchResults![$0.item] as! PHAsset}
        
        return assets
    }
    
    //MARK: - Actions
    
    @IBAction func handleAddButtonItem(_: AnyObject) {
        // Create a random dummy image.
        let rect = rand() % 2 == 0 ? CGRectMake(0, 0, 400, 300) : CGRectMake(0, 0, 300, 400)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)
        UIColor(hue: CGFloat(rand() % 100) / 100, saturation: 1.0, brightness: 1.0, alpha: 1.0).setFill()
        UIRectFillUsingBlendMode(rect, CGBlendMode.Normal)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Add it to the photo library
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(image)
            
            if self.assetCollection != nil {
                let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(forAssetCollection: self.assetCollection!)
                assetCollectionChangeRequest?.addAssets([assetChangeRequest.placeholderForCreatedAsset!] as NSArray)
            }
            }, completionHandler: {success, error in
                if !success {
                    NSLog("Error creating asset: %@", error!)
                }
        })
    }
    
    
}