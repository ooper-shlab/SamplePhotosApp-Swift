//
//  AAPLGridViewCell.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/25.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 A collection view cell that displays a thumbnail image.
 */

import UIKit


@objc(AAPLGridViewCell)
class GridViewCell: UICollectionViewCell {
    
    var thumbnailImage: UIImage? {
        didSet {
            didSetThumbnailImage(oldValue)
        }
    }
    var livePhotoBadgeImage: UIImage? {
        didSet {
            didSetLivePhotoBadgeImage(oldValue)
        }
    }
    var representedAssetIdentifier: String?
    
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var livePhotoBadgeImageView: UIImageView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.image = nil
        self.self.livePhotoBadgeImageView.image = nil
    }
    
    private func didSetThumbnailImage(_: UIImage?) {
        self.imageView.image = thumbnailImage
    }
    
    private func didSetLivePhotoBadgeImage(_: UIImage?) {
        self.livePhotoBadgeImageView.image = livePhotoBadgeImage
    }
    
}