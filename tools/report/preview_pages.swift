// Renders every page of a PDF to a PNG and prints how much text each page
// carries, so a blank or near-empty page shows up without opening anything.
//
//     swift tools/report/preview_pages.swift report.pdf out_dir [dpi]
//
// sips only rasterises the first page of a PDF, which is why this exists.
import AppKit
import Foundation
import PDFKit

let args = CommandLine.arguments
guard args.count >= 3 else {
  FileHandle.standardError.write(Data("usage: preview_pages.swift file.pdf out_dir [dpi]\n".utf8))
  exit(2)
}
let dpi = args.count > 3 ? (Double(args[3]) ?? 100) : 100
guard let document = PDFDocument(url: URL(fileURLWithPath: args[1])) else {
  FileHandle.standardError.write(Data("cannot open \(args[1])\n".utf8))
  exit(1)
}
let outDir = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let scale = dpi / 72.0
for index in 0..<document.pageCount {
  guard let page = document.page(at: index) else { continue }
  let box = page.bounds(for: .mediaBox)
  let width = Int((box.width * scale).rounded())
  let height = Int((box.height * scale).rounded())
  guard let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { continue }
  context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  context.scaleBy(x: scale, y: scale)
  page.draw(with: .mediaBox, to: context)
  guard let image = context.makeImage() else { continue }
  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
  let name = String(format: "p%02d.png", index + 1)
  try png.write(to: outDir.appendingPathComponent(name))
  let characters = (page.string ?? "").filter { !$0.isWhitespace }.count
  print(String(format: "page %2d  %5d chars", index + 1, characters))
}
print("\(document.pageCount) pages")
