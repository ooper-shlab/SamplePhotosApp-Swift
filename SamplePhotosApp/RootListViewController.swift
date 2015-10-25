//
//  AAPLRootListViewController.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/25.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 The view controller displaying the root list of the app.
 */

import UIKit
import Photos

private let AllPhotosReuseIdentifier = "AllPhotosCell"
private let CollectionCellReuseIdentifier = "CollectionCell"

private let AllPhotosSegue = "showAllPhotos"
private let CollectionSegue = "showCollection"

@objc(AAPLRootListViewController)
class RootListViewController: UITableViewController, PHPhotoLibraryChangeObserver {
    
    
    private var sectionFetchResults: [PHFetchResult] = []
    private var sectionLocalizedTitles: [String] = []
    
    override func awakeFromNib() {
        // Create a PHFetchResult object for each section in the table view.
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let allPhotos = PHAsset.fetchAssetsWithOptions(allPhotosOptions)
        
        let smartAlbums = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .AlbumRegular, options: nil)
        
        let topLevelUserCollections = PHCollectionList.fetchTopLevelUserCollectionsWithOptions(nil)
        
        // Store the PHFetchResult objects and localized titles for each section.
        self.sectionFetchResults = [allPhotos, smartAlbums, topLevelUserCollections]
        self.sectionLocalizedTitles = ["", NSLocalizedString("Smart Albums", comment: ""), NSLocalizedString("Albums", comment: "")]
        
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    //MARK: - UIViewController
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        /*
        Get the AAPLAssetGridViewController being pushed and the UITableViewCell
        that triggered the segue.
        */
        guard let
            assetGridViewController = segue.destinationViewController as? AssetGridViewController,
            cell = sender as? UITableViewCell
            else {
                return
        }
        
        // Set the title of the AAPLAssetGridViewController.
        assetGridViewController.title = cell.textLabel?.text
        
        // Get the PHFetchResult for the selected section.
        let indexPath = self.tableView.indexPathForCell(cell)!
        let fetchResult = self.sectionFetchResults[indexPath.section]
        
        if segue.identifier == AllPhotosSegue {
            assetGridViewController.assetsFetchResults = fetchResult
        } else if segue.identifier == CollectionSegue {
            // Get the PHAssetCollection for the selected row.
            guard let assetCollection = fetchResult[indexPath.row] as? PHAssetCollection else {
                return
            }
            
            // Configure the AAPLAssetGridViewController with the asset collection.
            let assetsFetchResult = PHAsset.fetchAssetsInAssetCollection(assetCollection, options: nil)
            
            assetGridViewController.assetsFetchResults = assetsFetchResult
            assetGridViewController.assetCollection = assetCollection
        }
    }
    
    //MARK: - UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.sectionFetchResults.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRows = 0
        
        if section == 0 {
            // The "All Photos" section only ever has a single row.
            numberOfRows = 1
        } else {
            let fetchResult = self.sectionFetchResults[section]
            numberOfRows = fetchResult.count
        }
        
        return numberOfRows
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        if indexPath.section == 0 {
            cell = tableView.dequeueReusableCellWithIdentifier(AllPhotosReuseIdentifier, forIndexPath: indexPath)
            cell.textLabel!.text = NSLocalizedString("All Photos", comment: "")
        } else {
            let fetchResult = self.sectionFetchResults[indexPath.section]
            let collection = fetchResult[indexPath.row] as! PHCollection
            
            cell = tableView.dequeueReusableCellWithIdentifier(CollectionCellReuseIdentifier, forIndexPath: indexPath)
            cell.textLabel!.text = collection.localizedTitle
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sectionLocalizedTitles[section]
    }
    
    //MARK: - PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(changeInstance: PHChange) {
        /*
        Change notifications may be made on a background queue. Re-dispatch to the
        main queue before acting on the change as we'll be updating the UI.
        */
        dispatch_async(dispatch_get_main_queue()) {
            // Loop through the section fetch results, replacing any fetch results that have been updated.
            var updatedSectionFetchResults = self.sectionFetchResults
            var reloadRequired = false
            
            self.sectionFetchResults.enumerate().forEach{index, collectionsFetchResult in
                if let changeDetails = changeInstance.changeDetailsForFetchResult(collectionsFetchResult) {
                    
                    updatedSectionFetchResults[index] = changeDetails.fetchResultAfterChanges
                    reloadRequired = true
                }
            }
            
            if reloadRequired {
                self.sectionFetchResults = updatedSectionFetchResults
                self.tableView.reloadData()
            }
            
        }
    }
    
    //MARK: - Actions
    
    @IBAction func handleAddButtonItem(_: AnyObject) {
        // Prompt user from new album title.
        let alertController = UIAlertController(title: NSLocalizedString("New Album", comment: ""), message: nil, preferredStyle: .Alert)
        
        alertController.addTextFieldWithConfigurationHandler{textField in
            textField.placeholder = NSLocalizedString("Album Name", comment: "")
        }
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil))
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Create", comment: ""), style: .Default) {action in
            let textField = alertController.textFields![0]
            guard let title = textField.text where !title.isEmpty else {
                return
            }
            
            // Create a new album with the title entered.
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollectionWithTitle(title)
                }, completionHandler: {success, error in
                    if !success {
                        NSLog("Error creating album: %@", error!)
                    }
            })
            })
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
}