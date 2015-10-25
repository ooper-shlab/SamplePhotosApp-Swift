//
//  UICollectionView+Convenience.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/25.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 A category on UICollectionView for convienience methods.
 */

import UIKit

extension UICollectionView {

    //### returns empty Array, rather than nil, when no elements in rect.
    func aapl_indexPathsForElementsInRect(rect: CGRect) -> [NSIndexPath] {
        guard let allLayoutAttributes = self.collectionViewLayout.layoutAttributesForElementsInRect(rect)
        else {return []}
        let indexPaths = allLayoutAttributes.map{$0.indexPath}
        return indexPaths
    }

}