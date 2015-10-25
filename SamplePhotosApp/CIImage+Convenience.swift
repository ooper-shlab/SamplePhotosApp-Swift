//
//  CIImage+Convenience.swift
//  SamplePhotosApp
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/25.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 A category on CIImage for convienience methods.
 */

import CoreImage
import UIKit

private let ciContext: CIContext = {
    let eaglContext = EAGLContext(API: EAGLRenderingAPI.OpenGLES2)
    return CIContext(EAGLContext: eaglContext)
}()

extension CIImage {
    
    func aapl_jpegRepresentationWithCompressionQuality(compressionQuality: CGFloat) -> NSData? {
        let outputImageRef = ciContext.createCGImage(self, fromRect: self.extent)
        let uiImage = UIImage(CGImage: outputImageRef, scale: 1.0, orientation: .Up)
        let jpegRepresentation = UIImageJPEGRepresentation(uiImage, compressionQuality)
        return jpegRepresentation
    }
    
}