//
//  AAPLGridViewCell.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/25.
//
//
/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:

  A collection view cell that displays a thumbnail image.

 */

import UIKit


@objc(AAPLGridViewCell)
class GridViewCell: UICollectionViewCell {

    var thumbnailImage: UIImage! {
        didSet {
            didSetThumbnailImage()
        }
    }

    @IBOutlet private var imageView: UIImageView!

    private func didSetThumbnailImage() {
        self.imageView.image = thumbnailImage
    }

}