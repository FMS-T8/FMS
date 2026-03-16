import Foundation
import UIKit
import Vision
import VisionKit

protocol DriverLicenseOCRServicing {
  func extract(from scan: VNDocumentCameraScan) async throws -> DriverLicenseScanResult
}

enum DriverLicenseOCRServiceError: LocalizedError {
  case noTextFound

  var errorDescription: String? {
    switch self {
    case .noTextFound:
      return "No readable text was found on the license. Try scanning again in better lighting."
    }
  }
}

struct LicenseParserService {
  private enum CharacterExpectation {
    case numeric
    case date
    case alphanumeric
  }

  private let structuredLicenseRegex = try? NSRegularExpression(
    pattern: #"\b([A-Z]{2})[-\s]?([0-9]{2})[-\s]?([0-9]{4})[-\s]?([0-9]{7})\b"#
  )
  private let generalLicenseRegex = try? NSRegularExpression(pattern: #"\b[A-Z0-9]{8,15}\b"#)
  private let dateRegex = try? NSRegularExpression(pattern: #"\b\d{2}[-/]\d{2}[-/]\d{4}\b"#)

  private let licenseAnchors = ["DL NO", "DL", "LIC", "LICENSE", "LICENCE", "NO", "DLN"]
  private let expiryAnchors = ["EXP", "EXPIRY", "VALID TILL", "VALIDITY", "VALID UPTO", "NT", "TR"]
  private let ignoreDateAnchors = ["DOB", "ISSUE"]

  func parse(recognizedLines: [String]) -> DriverLicenseScanResult {
    let normalizedLines = normalizeLines(recognizedLines)
    let rawText = normalizedLines.joined(separator: "\n")

    let fullName = extractName(from: normalizedLines)
    let licenseNumber = extractLicenseNumber(from: normalizedLines, rawText: rawText)
    let dateOfBirth = extractDOB(from: normalizedLines)
    let expiryDate = extractExpiryDate(from: normalizedLines)

    return DriverLicenseScanResult(
      fullName: fullName,
      licenseNumber: licenseNumber,
      dateOfBirth: dateOfBirth,
      expiryDate: expiryDate,
      rawLines: normalizedLines
    )
  }

  private func normalizeLines(_ lines: [String]) -> [String] {
    let combined = lines.joined(separator: "\n")
    let normalizedBreaks = combined.replacingOccurrences(of: #"\r\n|\r"#, with: "\n", options: .regularExpression)

    return normalizedBreaks
      .split(separator: "\n")
      .map { line in
        line
          .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .uppercased()
      }
      .filter { !$0.isEmpty }
  }

  private func correctOpticalAnomalies(_ input: String, expecting: CharacterExpectation) -> String {
    var map: [Character: Character] = [:]

    switch expecting {
    case .numeric, .date:
      map = ["O": "0", "I": "1", "L": "1", "S": "5", "B": "8", "Z": "2", "Q": "0"]
    case .alphanumeric:
      map = ["O": "0", "I": "1", "S": "5"]
    }

    var output = ""
    output.reserveCapacity(input.count)

    for char in input {
      let upper = Character(String(char).uppercased())
      output.append(map[upper] ?? upper)
    }

    return output
  }

  private func extractLicenseNumber(from lines: [String], rawText: String) -> String {
    // Regex pass: strict regional style first.
    if let strict = firstMatch(in: rawText, regex: structuredLicenseRegex) {
      let normalized = strict.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
      return normalized.replacingOccurrences(of: "--", with: "-")
    }

    // Anchor-proximity fallback: same line, then immediate next line.
    for index in lines.indices {
      let line = lines[index]
      guard containsAnyAnchor(line, anchors: licenseAnchors) else { continue }

      if let sameLine = extractFirstLicenseToken(from: stripAnchorPrefix(from: line)) {
        return sameLine
      }

      if index + 1 < lines.count,
         let nextLine = extractFirstLicenseToken(from: lines[index + 1]) {
        return nextLine
      }
    }

    // Regex pass: generic alphanumeric fallback, including OCR anomaly correction.
    for line in lines {
      let candidateLine = correctOpticalAnomalies(line, expecting: .alphanumeric)
      if let token = firstMatch(in: candidateLine, regex: generalLicenseRegex), isLikelyLicenseToken(token) {
        return token
      }
    }

    return ""
  }

  private func extractExpiryDate(from lines: [String]) -> Date? {
    var candidates: [Date] = []

    for index in lines.indices {
      let line = lines[index]
      guard !containsAnyAnchor(line, anchors: ignoreDateAnchors) else { continue }
      guard containsAnyAnchor(line, anchors: expiryAnchors) else { continue }

      if let same = extractDate(from: line), !containsAnyAnchor(line, anchors: ignoreDateAnchors) {
        candidates.append(same)
      }

      if index + 1 < lines.count {
        let nextLine = lines[index + 1]
        if !containsAnyAnchor(nextLine, anchors: ignoreDateAnchors),
           let next = extractDate(from: nextLine) {
          candidates.append(next)
        }
      }
    }

    if let best = candidates.max() {
      return best
    }

    // Final fallback: choose latest date not marked as DOB/ISSUE.
    let globalDates = lines
      .filter { !containsAnyAnchor($0, anchors: ignoreDateAnchors) }
      .compactMap(extractDate(from:))

    return globalDates.max()
  }

  private func extractDOB(from lines: [String]) -> Date? {
    for index in lines.indices {
      let line = lines[index]
      guard line.contains("DOB") || line.contains("DATE OF BIRTH") else { continue }

      if let same = extractDate(from: line) {
        return same
      }

      if index + 1 < lines.count, let next = extractDate(from: lines[index + 1]) {
        return next
      }
    }

    return nil
  }

  private func extractName(from lines: [String]) -> String {
    for index in lines.indices {
      let line = lines[index]
      guard line.contains("NAME") || line.contains("DRIVER NAME") else { continue }

      let sameLine = line.replacingOccurrences(of: #"^.*NAME\s*[:\-]?\s*"#, with: "", options: .regularExpression)
      if isLikelyName(sameLine) { return sameLine }

      if index + 1 < lines.count, isLikelyName(lines[index + 1]) {
        return lines[index + 1]
      }
    }

    let fallback = lines
      .filter(isLikelyName(_:))
      .max(by: { $0.count < $1.count })

    return fallback ?? ""
  }

  private func extractFirstLicenseToken(from text: String) -> String? {
    let corrected = correctOpticalAnomalies(text, expecting: .alphanumeric)

    if let structured = firstMatch(in: corrected, regex: structuredLicenseRegex) {
      return structured.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
    }

    if let generic = firstMatch(in: corrected, regex: generalLicenseRegex), isLikelyLicenseToken(generic) {
      return generic
    }

    return nil
  }

  private func extractDate(from text: String) -> Date? {
    let corrected = correctOpticalAnomalies(text, expecting: .date)
    guard let token = firstMatch(in: corrected, regex: dateRegex) else { return nil }
    return parseDate(token)
  }

  private func parseDate(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    let calendar = Calendar.current

    for format in ["dd/MM/yyyy", "dd-MM-yyyy", "MM/dd/yyyy", "MM-dd-yyyy"] {
      formatter.dateFormat = format
      if let date = formatter.date(from: value) {
        return calendar.startOfDay(for: date)
      }
    }

    return nil
  }

  private func firstMatch(in text: String, regex: NSRegularExpression?) -> String? {
    guard let regex else { return nil }
    let range = NSRange(location: 0, length: text.utf16.count)
    guard let match = regex.firstMatch(in: text, range: range),
          let swiftRange = Range(match.range, in: text)
    else {
      return nil
    }
    return String(text[swiftRange])
  }

  private func containsAnyAnchor(_ line: String, anchors: [String]) -> Bool {
    anchors.contains { anchor in
      let escapedAnchor = NSRegularExpression.escapedPattern(for: anchor)
      return line.range(of: "\\b\(escapedAnchor)\\b", options: .regularExpression) != nil
    }
  }

  private func stripAnchorPrefix(from line: String) -> String {
    line
      .replacingOccurrences(of: #"\b(DL\s*NO|DLN|DL|LICENCE|LICENSE|LIC|NO)\b\s*[:\-]?\s*"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func isLikelyLicenseToken(_ token: String) -> Bool {
    let compact = token.replacingOccurrences(of: "-", with: "")
    guard compact.count >= 8 && compact.count <= 15 else { return false }
    guard compact.rangeOfCharacter(from: .decimalDigits) != nil else { return false }
    return compact != "DRIVINGLICENSE"
  }

  private func isLikelyName(_ text: String) -> Bool {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.count >= 4 else { return false }
    guard cleaned.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
    return cleaned.split(separator: " ").count >= 2
  }
}

final class DriverLicenseOCRService: DriverLicenseOCRServicing {
  private let parser = LicenseParserService()

  func extract(from scan: VNDocumentCameraScan) async throws -> DriverLicenseScanResult {
    var allLines: [String] = []

    for pageIndex in 0..<scan.pageCount {
      let image = scan.imageOfPage(at: pageIndex)
      let lines = try await recognizeLines(in: image)
      allLines.append(contentsOf: lines)
    }

    let cleanedLines = allLines
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !cleanedLines.isEmpty else {
      throw DriverLicenseOCRServiceError.noTextFound
    }

    return parser.parse(recognizedLines: cleanedLines)
  }

  private func recognizeLines(in image: UIImage) async throws -> [String] {
    guard let cgImage = image.cgImage else { return [] }

    return try await withCheckedThrowingContinuation { continuation in
      let request = VNRecognizeTextRequest { request, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }

        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        continuation.resume(returning: lines)
      }

      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = false
      request.minimumTextHeight = 0.015

      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      do {
        try handler.perform([request])
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}
