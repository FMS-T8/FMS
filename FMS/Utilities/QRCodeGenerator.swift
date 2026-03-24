//
//  QRCodeGenerator.swift
//  FMS
//

import SwiftUI
import CoreImage.CIFilterBuiltins

/// A utility to generate QR code images from strings.
public enum QRCodeGenerator {
    private static let context = CIContext()

    /// Generates a QR code image for the given string.
    /// - Parameters:
    ///   - string: The data to encode in the QR code.
    ///   - size: The target size for the output image.
    /// - Returns: A `UIImage` if successful, otherwise `nil`.
    public static func generate(from string: String, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            // Calculate scale to fit the target size
            let scaleX = size.width / outputImage.extent.width
            let scaleY = size.height / outputImage.extent.height
            
            // Adjust to maintain aspect ratio and crispness
            let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
}
