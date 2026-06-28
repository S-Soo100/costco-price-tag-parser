// Vision OCR probe / fixture generator (macOS)
// Usage: swift tools/vision_ocr.swift <image1> [image2 ...]
// Output: JSON { "<filename>": [ {text, conf, x, yTop, w, h}, ... ], ... }
//   - coords normalized 0..1, origin TOP-LEFT (yTop=0 is top of image)
//   - same shape ML Kit gives us (text line + bounding box) so the Dart
//     parser we build against this output works unchanged on-device.
import Foundation
import Vision
import ImageIO
import CoreGraphics

func r(_ v: Double, _ scale: Double = 1000) -> Double { (v * scale).rounded() / scale }

func ocr(_ path: String) -> [[String: Any]] {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        FileHandle.standardError.write("cannot load: \(path)\n".data(using: .utf8)!)
        return []
    }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["ko-KR", "en-US"]
    req.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    do { try handler.perform([req]) }
    catch {
        FileHandle.standardError.write("ocr failed (\(path)): \(error)\n".data(using: .utf8)!)
        return []
    }
    var lines: [[String: Any]] = []
    for obs in (req.results ?? []) {
        guard let c = obs.topCandidates(1).first else { continue }
        let b = obs.boundingBox // normalized, bottom-left origin
        lines.append([
            "text": c.string,
            "conf": r(Double(c.confidence), 100),
            "x": r(Double(b.origin.x)),
            "yTop": r(1 - Double(b.origin.y) - Double(b.height)),
            "w": r(Double(b.width)),
            "h": r(Double(b.height)),
        ])
    }
    // top-to-bottom, then left-to-right reading order
    lines.sort {
        let ay = ($0["yTop"] as! Double), by = ($1["yTop"] as! Double)
        if abs(ay - by) > 0.02 { return ay < by }
        return ($0["x"] as! Double) < ($1["x"] as! Double)
    }
    return lines
}

let args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else {
    FileHandle.standardError.write("usage: swift vision_ocr.swift <image...>\n".data(using: .utf8)!)
    exit(1)
}
var result: [String: Any] = [:]
for p in args { result[(p as NSString).lastPathComponent] = ocr(p) }
if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
    print(String(data: data, encoding: .utf8)!)
}
