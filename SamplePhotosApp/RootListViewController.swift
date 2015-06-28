//
//  AAPLRootListViewController.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/25.
//
//
/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:

  The view controller displaying the root list of the app.

 */

import UIKit
import Photos

@objc(AAPLRootListViewController)
class RootListViewController: UITableViewController, PHPhotoLibraryChangeObserver {
    
    var collectionsFetchResults: [PHFetchResult] = []
    var collectionsLocalizedTitles: [String] = []
    
    private final let AllPhotosReuseIdentifier = "AllPhotosCell"
    private final let CollectionCellReuseIdentifier = "CollectionCell"
    
    private final let AllPhotosSegue = "showAllPhotos"
    private final let CollectionSegue = "showCollection"
    
    override func awakeFromNib() {
        let smartAlbums = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .AlbumRegular, options: nil)
        let topLevelUserCollections = PHCollectionList.fetchTopLevelUserCollectionsWithOptions(nil)
        self.collectionsFetchResults = [smartAlbums, topLevelUserCollections]
        self.collectionsLocalizedTitles = [NSLocalizedString("Smart Albums", comment: ""), NSLocalizedString("Albums", comment: "")]
        
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == AllPhotosSegue {
            let assetGridViewController = segue.destinationViewController as! AssetGridViewController
            // Fetch all assets, sorted by date created.
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending:true)]
            assetGridViewController.assetsFetchResults = PHAsset.fetchAssetsWithOptions(options)
            
        } else if segue.identifier == CollectionSegue {
            let assetGridViewController = segue.destinationViewController as! AssetGridViewController
            
            let indexPath = self.tableView.indexPathForCell(sender as! UITableViewCell)!
            let fetchResult = self.collectionsFetchResults[indexPath.section - 1] as PHFetchResult
            let collection = fetchResult[indexPath.row] as! PHCollection
            if collection is PHAssetCollection {
                let assetCollection = collection as! PHAssetCollection
                let assetsFetchResult = PHAsset.fetchAssetsInAssetCollection(assetCollection, options: nil)
                assetGridViewController.assetsFetchResults = assetsFetchResult
                assetGridViewController.assetCollection = assetCollection
            }
        }
    }
    
    //MARK: - UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1 + self.collectionsFetchResults.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRows = 0
        if section == 0 {
            numberOfRows = 1 // "All Photos" section
        } else {
            let fetchResult = self.collectionsFetchResults[section - 1] as PHFetchResult
            numberOfRows = fetchResult.count
        }
        return numberOfRows
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        var localizedTitle: String
        
        if indexPath.section == 0 {
            cell = tableView.dequeueReusableCellWithIdentifier(AllPhotosReuseIdentifier, forIndexPath: indexPath) as UITableViewCell
            localizedTitle = NSLocalizedString("All Photos", comment: "")
        } else {
            cell = tableView.dequeueReusableCellWithIdentifier(CollectionCellReuseIdentifier, forIndexPath: indexPath) as UITableViewCell
            let fetchResult = self.collectionsFetchResults[indexPath.section - 1] as PHFetchResult
            let collection = fetchResult[indexPath.row] as! PHCollection
            localizedTitle = collection.localizedTitle!
        }
        cell.textLabel?.text = localizedTitle
        
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String? = nil
        if section > 0 {
            title = self.collectionsLocalizedTitles[section - 1]
        }
        return title
    }
    
    //MARK: - PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(changeInstance: PHChange) {
        // Call might come on any background queue. Re-dispatch to the main queue to handle it.
        dispatch_async(dispatch_get_main_queue()) {
            
            var updatedCollectionsFetchResults: [PHFetchResult] = []
            
            for collectionsFetchResult in self.collectionsFetchResults {
                let changeDetails = changeInstance.changeDetailsForFetchResult(collectionsFetchResult)
                if changeDetails != nil {
                    if updatedCollectionsFetchResults.isEmpty {
                        updatedCollectionsFetchResults = self.collectionsFetchResults
                    }
                    let index = self.collectionsFetchResults.indexOf(collectionsFetchResult)
                    updatedCollectionsFetchResults[index!] = changeDetails!.fetchResultAfterChanges
                }
            }
            
            if !updatedCollectionsFetchResults.isEmpty {
                self.collectionsFetchResults = updatedCollectionsFetchResults
                self.tableView.reloadData()
            }
            
        }
    }
    
    //MARK: - Actions
    
    @IBAction func handleAddButtonItem(AnyObject) {
        // Prompt user from new album title.
        let alertController = UIAlertController(title: NSLocalizedString("New Album", comment: ""), message: nil, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil))
        alertController.addTextFieldWithConfigurationHandler {textField in
            textField.placeholder = NSLocalizedString("Album Name", comment: "")
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Create", comment: "") , style: .Default, handler: {action in
            let textField = alertController.textFields!.first! as UITextField
            let title = textField.text
            
            // Create new album.
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollectionWithTitle(title!)
                return
                }, completionHandler: {success, error in
                    if !success {
                        NSLog("Error creating album: %@", error!)
                    }
            })
        }))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
}