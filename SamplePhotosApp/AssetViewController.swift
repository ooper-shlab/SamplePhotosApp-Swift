//
//  AAPLAssetViewController.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/25.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 A view controller displaying an asset full screen.
 */

import UIKit
import Photos
import PhotosUI


@objc(AAPLAssetViewController)
class AssetViewController: UIViewController, PHPhotoLibraryChangeObserver {
    
    var asset: PHAsset?
    var assetCollection: PHAssetCollection?
    
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var editButton: UIBarButtonItem!
    @IBOutlet private weak var progressView: UIProgressView!
    @IBOutlet private var playButton: UIBarButtonItem!
    @IBOutlet private var space: UIBarButtonItem!
    @IBOutlet private var trashButton: UIBarButtonItem!
    
    private var playerLayer: AVPlayerLayer?
    private var lastTargetSize: CGSize = CGSize()
    private var playingHint: Bool = false
    
    private let AdjustmentFormatIdentifier = "com.example.apple-samplecode.SamplePhotosApp"
    
    //MARK: - View Lifecycle Methods.
    
    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set the appropriate toolbarItems based on the mediaType of the asset.
        if self.asset?.mediaType == PHAssetMediaType.Video {
            self.showPlaybackToolbar()
        } else {
            self.showStaticToolbar()
        }
        
        // Enable the edit button if the asset can be edited.
        let isEditable = (self.asset?.canPerformEditOperation(.Properties) ?? false) || (self.asset?.canPerformEditOperation(.Content) ?? true)
        self.editButton.enabled = isEditable
        
        // Enable the trash button if the asset can be deleted.
        var isTrashable = false
        if let assetCollection = self.assetCollection {
            isTrashable = assetCollection.canPerformEditOperation(.RemoveContent)
        } else {
            isTrashable = self.asset?.canPerformEditOperation(.Delete) ?? false
        }
        self.trashButton.enabled = isTrashable
        
        self.updateImage()
        
        self.view.layoutIfNeeded()
    }
    
    //MARK: - View & Toolbar setup methods.
    
    private func showStaticPhotoView() {
        self.imageView.hidden = false
    }
    
    private func showPlaybackToolbar() {
        self.toolbarItems = [self.playButton, self.space, self.trashButton]
    }
    
    private func showStaticToolbar() {
        self.toolbarItems = [self.space, self.trashButton]
    }
    
    private var targetSize: CGSize {
        let scale = UIScreen.mainScreen().scale
        let targetSize = CGSizeMake(CGRectGetWidth(self.imageView.bounds) * scale, CGRectGetHeight(self.imageView.bounds) * scale)
        return targetSize
    }
    
    //MARK: - ImageView/LivePhotoView Image Setting methods.
    
    private func updateImage() {
        self.lastTargetSize = self.targetSize
        
        self.updateStaticImage()
    }
    
    private func updateStaticImage() {
        // Prepare the options to pass when fetching the live photo.
        let options = PHImageRequestOptions()
        options.deliveryMode = .HighQualityFormat
        options.networkAccessAllowed = true
        options.progressHandler = {progress, error, stop, info in
            /*
            Progress callbacks may not be on the main thread. Since we're updating
            the UI, dispatch to the main queue.
            */
            dispatch_async(dispatch_get_main_queue()) {
                self.progressView.progress = Float(progress)
            }
        }
        
        PHImageManager.defaultManager().requestImageForAsset(self.asset!, targetSize: self.targetSize, contentMode: .AspectFit, options: options) {result, info in
            // Hide the progress view now the request has completed.
            self.progressView.hidden = true
            
            // Check if the request was successful.
            if result == nil {
                return
            }
            
            // Show the UIImageView and use it to display the requested image.
            self.showStaticPhotoView()
            self.imageView.image = result
        }
    }
    
    //MARK: - PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(changeInstance: PHChange) {
        // Call might come on any background queue. Re-dispatch to the main queue to handle it.
        dispatch_async(dispatch_get_main_queue()) {
            // Check if there are changes to the asset we're displaying.
            guard let
                asset = self.asset,
                changeDetails = changeInstance.changeDetailsForObject(asset) else {
                    return
            }
            
            // Get the updated asset.
            self.asset = changeDetails.objectAfterChanges as? PHAsset
            
            // If the asset's content changed, update the image and stop any video playback.
            if changeDetails.assetContentChanged {
                self.updateImage()
                
                self.playerLayer?.removeFromSuperlayer()
                self.playerLayer = nil
            }
        }
    }
    
    //MARK: - Target Action Methods.
    
    @IBAction func handleEditButtonItem(sender: AnyObject) {
        // Use a UIAlertController to display the editing options to the user.
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        alertController.modalPresentationStyle = .Popover
        alertController.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
        alertController.popoverPresentationController?.permittedArrowDirections = .Up
        
        // Add an action to dismiss the UIAlertController.
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil))
        
        // If PHAsset supports edit operations, allow the user to toggle its favorite status.
        if self.asset?.canPerformEditOperation(.Properties) ?? false {
            let favoriteActionTitle = !(self.asset?.favorite ?? false) ? NSLocalizedString("Favorite", comment: "") : NSLocalizedString("Unfavorite", comment: "")
            
            alertController.addAction(UIAlertAction(title: favoriteActionTitle, style: .Default) {action in
                self.toggleFavoriteState()
                })
        }
        
        // Only allow editing if the PHAsset supports edit operations and it is not a Live Photo.
        if self.isContentEditable {
            // Allow filters to be applied if the PHAsset is an image.
            if self.asset?.mediaType == PHAssetMediaType.Image {
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Sepia", comment: ""), style: .Default) {action in
                    self.applyFilterWithName("CISepiaTone")
                    })
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Chrome", comment: ""), style: .Default) {action in
                    self.applyFilterWithName("CIPhotoEffectChrome")
                    })
            }
            
            // Add actions to revert any edits that have been made to the PHAsset.
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Revert", comment: ""), style: .Default) {action in
                self.revertToOriginal()
                })
        }
        
        // Present the UIAlertController.
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    private var isContentEditable: Bool {
        return self.asset?.canPerformEditOperation(.Content) ?? false
    }
    
    @IBAction func handleTrashButtonItem(_: AnyObject) {
        let completionHandler: (Bool, NSError?)->Void = {success, error in
            if success {
                dispatch_async(dispatch_get_main_queue()) {
                    self.navigationController?.popViewControllerAnimated(true)
                }
            } else {
                NSLog("Error: %@", error!)
            }
        }
        
        if let assetCollection = self.assetCollection {
            // Remove asset from album
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let changeRequest = PHAssetCollectionChangeRequest(forAssetCollection: assetCollection)
                changeRequest?.removeAssets([self.asset!] as NSArray)
                }, completionHandler: completionHandler)
            
        } else {
            // Delete asset from library
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                PHAssetChangeRequest.deleteAssets([self.asset!] as NSArray)
                }, completionHandler: completionHandler)
            
        }
    }
    
    @IBAction func handlePlayButtonItem(_: AnyObject) {
        if self.playerLayer != nil {
            // An AVPlayerLayer has already been created for this asset.
            self.playerLayer!.player?.play()
        } else {
            // Request an AVAsset for the PHAsset we're displaying.
            PHImageManager.defaultManager().requestAVAssetForVideo(self.asset!, options: nil)
                {avAsset, audioMix, info in
                    dispatch_async(dispatch_get_main_queue()) {
                        if self.playerLayer == nil {
                            let viewLayer = self.view.layer
                            
                            // Create an AVPlayerItem for the AVAsset.
                            let playerItem = AVPlayerItem(asset: avAsset!)
                            playerItem.audioMix = audioMix
                            
                            // Create an AVPlayer with the AVPlayerItem.
                            let player = AVPlayer(playerItem: playerItem)
                            
                            // Create an AVPlayerLayer with the AVPlayer.
                            let playerLayer = AVPlayerLayer(player: player)
                            
                            // Configure the AVPlayerLayer and add it to the view.
                            playerLayer.videoGravity = AVLayerVideoGravityResizeAspect
                            playerLayer.frame = CGRectMake(0, 0, viewLayer.bounds.size.width, viewLayer.bounds.size.height)
                            
                            viewLayer.addSublayer(playerLayer)
                            player.play()
                            
                            // Store a reference to the player layer we added to the view.
                            self.playerLayer = playerLayer
                        }
                    }
            }
        }
    }
    
    //MARK: - Photo editing methods.
    
    private func applyFilterWithName(filterName: String) {
        // Prepare the options to pass when requesting to edit the image.
        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = {adjustmentData->Bool in
            adjustmentData.formatIdentifier == self.AdjustmentFormatIdentifier && adjustmentData.formatVersion == "1.0"
        }
        
        self.asset!.requestContentEditingInputWithOptions(options) {contentEditingInput, info in
            // Create a CIImage from the full image representation.
            let url = contentEditingInput!.fullSizeImageURL!
            let orientation = contentEditingInput!.fullSizeImageOrientation
            var inputImage = CIImage(contentsOfURL: url, options: nil)!
            inputImage = inputImage.imageByApplyingOrientation(orientation)
            
            // Create the filter to apply.
            let filter = CIFilter(name: filterName)!
            filter.setDefaults()
            filter.setValue(inputImage, forKey: kCIInputImageKey)
            
            // Apply the filter.
            let outputImage = filter.outputImage
            
            // Create a PHAdjustmentData object that describes the filter that was applied.
            let adjustmentData = PHAdjustmentData(formatIdentifier: self.AdjustmentFormatIdentifier, formatVersion: "1.0", data: filterName.dataUsingEncoding(NSUTF8StringEncoding)!)
            
            /*
            Create a PHContentEditingOutput object and write a JPEG representation
            of the filtered object to the renderedContentURL.
            */
            let contentEditingOutput = PHContentEditingOutput(contentEditingInput: contentEditingInput!)
            let jpegData = outputImage?.aapl_jpegRepresentationWithCompressionQuality(0.9)!
            jpegData?.writeToURL(contentEditingOutput.renderedContentURL, atomically: true)
            contentEditingOutput.adjustmentData = adjustmentData
            
            // Ask the shared PHPhotoLinrary to perform the changes.
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let request = PHAssetChangeRequest(forAsset: self.asset!)
                request.contentEditingOutput = contentEditingOutput
                }, completionHandler: {success, error in
                    if !success {
                        NSLog("Error: %@", error!)
                    }
            })
        }
    }
    
    private func toggleFavoriteState() {
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
            let request = PHAssetChangeRequest(forAsset: self.asset!)
            request.favorite = !self.asset!.favorite
            }, completionHandler: {success, error in
                if !success {
                    NSLog("Error: %@", error!)
                }
        })
    }
    
    private func revertToOriginal() {
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
            let request = PHAssetChangeRequest(forAsset: self.asset!)
            request.revertAssetContentToOriginal()
            }, completionHandler: {success, error in
                if !success {
                    NSLog("Error: %@", error!)
                }
        })
    }
    
}
@available(iOS 9.1, *)
@objc(AAPLLiveAssetViewController)
class LiveAssetViewController: AssetViewController, PHLivePhotoViewDelegate {
    
    @IBOutlet private weak var livePhotoView: PHLivePhotoView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.livePhotoView.delegate = self;
    }
    
    //MARK: - View & Toolbar setup methods.
    
    private func showLivePhotoView() {
        self.livePhotoView.hidden = false
        self.imageView.hidden = true
    }
    
    private override func showStaticPhotoView() {
        self.livePhotoView.hidden = true
        self.imageView.hidden = false
    }
    
    //MARK: - ImageView/LivePhotoView Image Setting methods.
    
    override private func updateImage() {
        self.lastTargetSize = self.targetSize
        
        // Check the asset's `mediaSubtypes` to determine if this is a live photo or not.
        let assetHasLivePhotoSubType = self.asset?.mediaSubtypes.contains(.PhotoLive) ?? false
        if assetHasLivePhotoSubType {
            self.updateLiveImage()
        } else {
            self.updateStaticImage()
        }
    }
    
    private func updateLiveImage() {
        // Prepare the options to pass when fetching the live photo.
        let livePhotoOptions = PHLivePhotoRequestOptions()
        livePhotoOptions.deliveryMode = .HighQualityFormat
        livePhotoOptions.networkAccessAllowed = true
        livePhotoOptions.progressHandler = {progress, error, stop, info in
            /*
            Progress callbacks may not be on the main thread. Since we're updating
            the UI, dispatch to the main queue.
            */
            dispatch_async(dispatch_get_main_queue()) {
                self.progressView.progress = Float(progress)
            }
        }
        
        // Request the live photo for the asset from the default PHImageManager.
        PHImageManager.defaultManager().requestLivePhotoForAsset(self.asset!, targetSize: self.targetSize, contentMode: .AspectFit, options: livePhotoOptions) {livePhoto, info in
            // Hide the progress view now the request has completed.
            self.progressView.hidden = true
            
            // Check if the request was successful.
            if livePhoto == nil {
                return
            }
            
            NSLog ("Got a live photo")
            
            // Show the PHLivePhotoView and use it to display the requested image.
            self.showLivePhotoView()
            self.livePhotoView.livePhoto = livePhoto
            
            if !(info![PHImageResultIsDegradedKey] as! Bool) && !self.playingHint {
                // Playback a short section of the live photo; similar to the Photos share sheet.
                NSLog ("playing hint...")
                self.playingHint = true
                self.livePhotoView.startPlaybackWithStyle(.Hint)
            }
            
            // Update the toolbar to show the correct items for a live photo.
            self.showPlaybackToolbar()
        }
    }
    
    //MARK: - PHLivePhotoViewDelegate Protocol Methods.
    
    func livePhotoView(livePhotoView: PHLivePhotoView, willBeginPlaybackWithStyle playbackStyle: PHLivePhotoViewPlaybackStyle) {
        NSLog("Will Beginning Playback of Live Photo...")
    }
    
    func livePhotoView(livePhotoView: PHLivePhotoView, didEndPlaybackWithStyle playbackStyle: PHLivePhotoViewPlaybackStyle) {
        NSLog("Did End Playback of Live Photo...")
        self.playingHint = false
    }
    
    //MARK: - Target Action Methods.
    
    @IBAction override func handlePlayButtonItem(sender: AnyObject) {
        if self.livePhotoView.livePhoto != nil {
            // We're displaying a live photo, begin playing it.
            self.livePhotoView.startPlaybackWithStyle(.Full)
        } else {
            super.handlePlayButtonItem(sender)
        }
    }
    private override var isContentEditable: Bool {
        return super.isContentEditable && !self.asset!.mediaSubtypes.contains(.PhotoLive)
    }
    
}
