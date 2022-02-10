//
//  VisionReq.swift
//
//  MultiLens AR
//
//  ex AlternativeARKit
//  Created by Andrew Zheng on 4/21/20.
//  Copyright © 2020 Zheng. All rights reserved.
//
//  Motion code and alts Dan Monaghan on 2/11/22.

import UIKit
import Vision

extension ViewController {
    func findUsingVision(in pixelBuffer: CVPixelBuffer) {
        
        busyPerformingVisionRequest = true
       
        DispatchQueue.global(qos: .userInitiated).async {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let width = ciImage.extent.width
            let height = ciImage.extent.height
            
            self.aspectRatioWidthOverHeight = height / width /// opposite, because the pixelbuffer is given to us sideways
            
            let request = VNRecognizeTextRequest { request, error in
                /// this function will be called when the Vision request finishes
//                self.handleFastDetectedText(request: request, error: error)
            }
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
            
            do {
                try imageRequestHandler.perform([request])
            } catch let error {
                print("Error: \(error)")
            }
        }
    }
    
    func handleDetect(request: VNRequest?, error: Error?) {
        /// We make sure that the results is not nil and there is at least one
        guard let results = request?.results, results.count > 0 else {
            busyPerformingVisionRequest = false
            return
        }
        
        /// Make the array of CGRects here:
        var rectangles = [CGRect]()
        
        for result in results {
            
            if let observation = result as? VNRecognizedTextObservation {
                
                /// topCandidates(1) returns us what Vision thinks are the most accurate results.
                /// It's a scale from 1 to 10, 1 is most accurate, 10 is least accurate and returns 10 different groups of words.
                for returnedObject in observation.topCandidates(1) {
                    
                    /// this is the text that Visino detects
                    let originalFoundText = returnedObject.string
                    
                    var x = observation.boundingBox.origin.x
                    var y = 1 - observation.boundingBox.origin.y
                    var height = observation.boundingBox.height
                    var width = observation.boundingBox.width
                    
                    /// We're not going have Vision be case-sensitive
                    let lowerCaseComponentText = originalFoundText.lowercased()
                    
                    /// we're going to do some converting
                    let convertedOriginalWidthOfBigImage = aspectRatioWidthOverHeight * deviceSize.height
                    let offsetWidth = convertedOriginalWidthOfBigImage - deviceSize.width
                    
                    /// The pixelbuffer that we got Vision to process is bigger then the device's screen, so we need to adjust it
                    let offHalf = offsetWidth / 2
                    
                    width *= convertedOriginalWidthOfBigImage
                    height *= deviceSize.height
                    x *= convertedOriginalWidthOfBigImage
                    x -= offHalf
                    y *= deviceSize.height
                    y -= height
                    
                    /// we're going to get the width of each character so we can correctly determine the x-position of matched text
  
                }
            }
        }
        
        DispatchQueue.main.async {
                // place final action here.
        }
        busyPerformingVisionRequest = false
    }
}
