//
//  AAPLAssetViewController.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/25.
//
//
/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:

  A view controller displaying an asset full screen.

 */

import UIKit
import Photos


extension CIImage {
    func aapl_jpegRepresentationWithCompressionQuality(compressionQuality: CGFloat) -> NSData {
        NSLog(__FUNCTION__ + " called")
        struct My {
            static var ciContext: CIContext!
        }
        if My.ciContext == nil {
            let eaglContext = EAGLContext(API: .OpenGLES2)
            My.ciContext = CIContext(EAGLContext: eaglContext)
        }
        let outputImageRef = My.ciContext.createCGImage(self, fromRect: self.extent)
        let uiImage = UIImage(CGImage: outputImageRef, scale: 1.0, orientation: .Up)
        let jpegRepresentation = UIImageJPEGRepresentation(uiImage, compressionQuality)
        return jpegRepresentation!
    }
}


@objc(AAPLAssetViewController)
class AssetViewController: UIViewController, PHPhotoLibraryChangeObserver {
    var asset: PHAsset!
    var assetCollection: PHAssetCollection?
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private var playButton: UIBarButtonItem!
    @IBOutlet private var space: UIBarButtonItem!
    @IBOutlet private var trashButton: UIBarButtonItem!
    @IBOutlet private var editButton: UIBarButtonItem!
    @IBOutlet private var progressView: UIProgressView!
    private var playerLayer: AVPlayerLayer?
    private var lastImageViewSize: CGSize = CGSize()
    
    final let AdjustmentFormatIdentifier = "com.example.apple-samplecode.SamplePhotosApp"
    
    deinit {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.asset.mediaType == PHAssetMediaType.Video {
            self.toolbarItems = [self.playButton, self.space, self.trashButton]
        } else {
            self.toolbarItems = [self.space, self.trashButton]
        }
        
        let isEditable = self.asset.canPerformEditOperation(PHAssetEditOperation.Properties) || self.asset.canPerformEditOperation(PHAssetEditOperation.Content)
        self.editButton.enabled = isEditable
        
        var isTrashable = false
        if self.assetCollection != nil {
            isTrashable = self.assetCollection!.canPerformEditOperation(.RemoveContent)
        } else {
            isTrashable = self.asset.canPerformEditOperation(.Delete)
        }
        self.trashButton.enabled = isTrashable
        
        self.view.layoutIfNeeded()
        self.updateImage()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if !CGSizeEqualToSize(self.imageView.bounds.size, self.lastImageViewSize) {
            self.updateImage()
        }
    }
    
    private func updateImage() {
        self.lastImageViewSize = self.imageView.bounds.size
        
        let scale = UIScreen.mainScreen().scale
        let targetSize = CGSizeMake(CGRectGetWidth(self.imageView.bounds) * scale, CGRectGetHeight(self.imageView.bounds) * scale)
        
        let options = PHImageRequestOptions()
        
        // Download from cloud if necessary
        options.networkAccessAllowed = true
        options.progressHandler = {progress, error, stop, info in
            dispatch_async(dispatch_get_main_queue()) {
                self.progressView.progress = Float(progress)
                self.progressView.hidden = (progress <= 0.0 || progress >= 1.0)
            }
        }
        
        PHImageManager.defaultManager().requestImageForAsset(self.asset, targetSize: targetSize, contentMode: .AspectFit, options: options) {result, info in
            if result != nil {
                self.imageView.image = result
            }
        }
    }
    
    //MARK: - PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(changeInstance: PHChange) {
        // Call might come on any background queue. Re-dispatch to the main queue to handle it.
        dispatch_async(dispatch_get_main_queue()) {
            
            // check if there are changes to the album we're interested on (to its metadata, not to its collection of assets)
            let changeDetails = changeInstance.changeDetailsForObject(self.asset)
            if changeDetails != nil {
                // it changed, we need to fetch a new one
                self.asset = changeDetails!.objectAfterChanges as! PHAsset
                
                if changeDetails!.assetContentChanged {
                    self.updateImage()
                    
                    if self.playerLayer != nil {
                        self.playerLayer!.removeFromSuperlayer()
                        self.playerLayer = nil
                    }
                }
            }
            
        }
    }
    
    //MARK: - Actions
    
    private func applyFilterWithName(filterName: String) {
        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = {adjustmentData in
            return adjustmentData.formatIdentifier == self.AdjustmentFormatIdentifier && adjustmentData.formatVersion == "1.0"
        }
        self.asset.requestContentEditingInputWithOptions(options) {contentEditingInput, info in
            // Get full image
            let url = contentEditingInput!.fullSizeImageURL
            let orientation = contentEditingInput!.fullSizeImageOrientation
            var inputImage = CIImage(contentsOfURL: url!, options: nil)
            inputImage = inputImage!.imageByApplyingOrientation(orientation)
            
            // Add filter
            let filter = CIFilter(name: filterName)
            filter!.setDefaults()
            filter!.setValue(inputImage, forKey: kCIInputImageKey)
            let outputImage = filter!.outputImage
            
            // Create editing output
            let jpegData = outputImage!.aapl_jpegRepresentationWithCompressionQuality(0.9)
            let adjustmentData = PHAdjustmentData(formatIdentifier: self.AdjustmentFormatIdentifier, formatVersion: "1.0", data: filterName.dataUsingEncoding(NSUTF8StringEncoding)!)
            
            let contentEditingOutput = PHContentEditingOutput(contentEditingInput: contentEditingInput!)
            jpegData.writeToURL(contentEditingOutput.renderedContentURL, atomically: true)
            contentEditingOutput.adjustmentData = adjustmentData
            
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let request = PHAssetChangeRequest(forAsset: self.asset)
                request.contentEditingOutput = contentEditingOutput
                }) {success, error in
                    if !success {
                        NSLog("Error: %@", error!)
                    }
            }
        }
    }
    
    @IBAction func handleEditButtonItem(sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil))
        
        if self.asset.canPerformEditOperation(.Properties) {
            let favoriteActionTitle = !self.asset.favorite ? NSLocalizedString("Favorite", comment: "") : NSLocalizedString("Unfavorite", comment: "")
            alertController.addAction(UIAlertAction(title: favoriteActionTitle, style: .Default) {action in
                PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                    let request = PHAssetChangeRequest(forAsset: self.asset)
                    request.favorite = !self.asset.favorite
                    }, completionHandler: { success, error in
                        if !success {
                            NSLog("Error: %@", error!)
                        }
                })
                })
        }
        if self.asset.canPerformEditOperation(.Content) {
            if self.asset.mediaType == .Image {
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Sepia", comment: ""), style: .Default) {action in
                    self.applyFilterWithName("CISepiaTone")
                    })
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Chrome", comment: ""), style: .Default) {action in
                    self.applyFilterWithName("CIPhotoEffectChrome")
                    })
            }
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Revert", comment: ""), style: .Default) {action in
                PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                    let request = PHAssetChangeRequest(forAsset: self.asset)
                    request.revertAssetContentToOriginal()
                    }, completionHandler: {success, error in
                        if !success {
                            NSLog("Error: %@", error!)
                        }
                })
                })
        }
        alertController.modalPresentationStyle = .Popover
        self.presentViewController(alertController, animated: true, completion: nil)
        alertController.popoverPresentationController?.barButtonItem = sender
        alertController.popoverPresentationController?.permittedArrowDirections = .Up
    }
    
    @IBAction func handleTrashButtonItem(_: AnyObject) {
        let completionHandler: (Bool, NSError?)->Void = {success, error in
            if success {
                dispatch_async(dispatch_get_main_queue()) {
                    self.navigationController?.popViewControllerAnimated(true)
                    return
                }
            } else {
                NSLog("Error: %@", error!)
            }
        }
        
        if self.assetCollection != nil {
            // Remove asset from album
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let changeRequest = PHAssetCollectionChangeRequest(forAssetCollection: self.assetCollection!)
                changeRequest!.removeAssets([self.asset])
                }, completionHandler: completionHandler)
            
        } else {
            // Delete asset from library
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                PHAssetChangeRequest.deleteAssets([self.asset])
                }, completionHandler: completionHandler)
            
        }
    }
    
    @IBAction func handlePlayButtonItem(_: AnyObject) {
        if self.playerLayer == nil {
            PHImageManager.defaultManager().requestAVAssetForVideo(self.asset, options: nil) {avAsset, audioMix, info in
                dispatch_async(dispatch_get_main_queue()) {
                    if self.playerLayer != nil {
                        let playerItem = AVPlayerItem(asset: avAsset!)
                        playerItem.audioMix = audioMix
                        let player = AVPlayer(playerItem: playerItem)
                        let playerLayer = AVPlayerLayer(player: player)
                        playerLayer.videoGravity = AVLayerVideoGravityResizeAspect
                        
                        let layer = self.view.layer
                        layer.addSublayer(playerLayer)
                        playerLayer.frame = layer.bounds
                        player.play()
                    }
                }
            }
            
        } else {
            self.playerLayer!.player!.play()
        }
        
    }
    
}