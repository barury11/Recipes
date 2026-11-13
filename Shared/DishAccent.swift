import CoreGraphics
import CoreVideo
import SwiftUI
import Vision

struct DishAccent {
    let red: Double
    let green: Double
    let blue: Double

    static let fallback = Self(red: 0.44, green: 0.44, blue: 0.46)

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var labelColor: Color {
        let luminance = 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
        return luminance > 0.179 ? .black : .white
    }

    static func extract(from image: CGImage) -> Self? {
        let side = 80
        let bytesPerRow = side * 4
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ), let data = context.data else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        let pixels = data.assumingMemoryBound(to: UInt8.self)

        let labels = foregroundLabels(for: image, sampleSide: side)
        let subject = labels.flatMap { mainSubject(in: $0, side: side) }
        let hueCount = 24
        var clusters = Array(repeating: Cluster(), count: hueCount + 1)

        for y in 0..<side {
            for x in 0..<side {
                if let subject, let labels, labels[y * side + x] != subject { continue }
                let center = centerWeight(x: x, y: y, side: side)
                if subject == nil, center < 0.62 { continue }

                let offset = y * bytesPerRow + x * 4
                let alpha = Double(pixels[offset + 3]) / 255
                guard alpha >= 0.5 else { continue }

                let pixel = Self(
                    red: Double(pixels[offset]) / 255 / alpha,
                    green: Double(pixels[offset + 1]) / 255 / alpha,
                    blue: Double(pixels[offset + 2]) / 255 / alpha
                )
                let brightest = max(pixel.red, pixel.green, pixel.blue)
                let darkest = min(pixel.red, pixel.green, pixel.blue)
                let chroma = brightest - darkest
                let weight = 0.3 + 0.7 * center

                if chroma < 0.10 {
                    // Neutral pixels often belong to a plate or a reflection.
                    clusters[hueCount].add(pixel, weight: weight * 0.14)
                    continue
                }

                let hue: Double
                if brightest == pixel.red {
                    hue = (pixel.green - pixel.blue) / chroma
                } else if brightest == pixel.green {
                    hue = 2 + (pixel.blue - pixel.red) / chroma
                } else {
                    hue = 4 + (pixel.red - pixel.green) / chroma
                }
                let position = (hue + (hue < 0 ? 6 : 0)) / 6 * Double(hueCount)
                let lower = Int(position)
                let fraction = position - Double(lower)
                let coloredWeight = weight * (0.4 + 0.6 * chroma)
                clusters[lower % hueCount].add(pixel, weight: coloredWeight * (1 - fraction))
                clusters[(lower + 1) % hueCount].add(pixel, weight: coloredWeight * fraction)
            }
        }

        guard let dominant = clusters.max(by: { $0.weight < $1.weight }),
              dominant.weight > 0 else { return nil }
        return dominant.color
    }

    private static func foregroundLabels(for image: CGImage, sampleSide: Int) -> [UInt8]? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        guard (try? handler.perform([request])) != nil,
              let result = request.results?.first,
              !result.allInstances.isEmpty else { return nil }

        let buffer = result.instanceMask
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent8,
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }

        let labels = base.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)

        return (0..<(sampleSide * sampleSide)).map { index in
            let x = (2 * (index % sampleSide) + 1) * width / (2 * sampleSide)
            let y = (2 * (index / sampleSide) + 1) * height / (2 * sampleSide)
            return labels[y * stride + x]
        }
    }

    private static func mainSubject(in labels: [UInt8], side: Int) -> UInt8? {
        var scores: [UInt8: Double] = [:]
        for (index, label) in labels.enumerated() where label != 0 {
            let center = centerWeight(x: index % side, y: index / side, side: side)
            scores[label, default: 0] += center * center
        }
        return scores.max {
            $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value
        }?.key
    }

    private static func centerWeight(x: Int, y: Int, side: Int) -> Double {
        let horizontal = (Double(x) + 0.5) / Double(side) - 0.5
        let vertical = (Double(y) + 0.5) / Double(side) - 0.5
        return max(0, 1 - 2 * (horizontal * horizontal + vertical * vertical))
    }

    private func linearize(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    private struct Cluster {
        var weight = 0.0
        var red = 0.0
        var green = 0.0
        var blue = 0.0

        mutating func add(_ pixel: DishAccent, weight: Double) {
            self.weight += weight
            red += pixel.red * weight
            green += pixel.green * weight
            blue += pixel.blue * weight
        }

        var color: DishAccent {
            DishAccent(red: red / weight, green: green / weight, blue: blue / weight)
        }
    }
}
