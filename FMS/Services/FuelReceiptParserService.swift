import Foundation
import CoreLocation

struct FuelReceiptParserService {
  private let dateRegex = try? NSRegularExpression(pattern: #"\b\d{1,2}[-/.](?:\d{1,2}|[A-Z]{3})[-/.]\d{2,4}\b"#)
  private let timeRegex = try? NSRegularExpression(pattern: #"\b\d{1,2}:\d{2}(?::\d{2})?(?:\s?(?:AM|PM))?\b"#)
  private let decimalRegex = try? NSRegularExpression(pattern: #"\b\d+(?:[.,]\d{1,3})?\b"#)

  private let amountAnchors = ["TOTAL", "AMOUNT"]
  private let volumeAnchors = ["VOL", "VOLUME", "QTY"]

  func parse(
    recognizedLines: [String],
    manualEntry: ManualFuelEntry? = nil,
    gpsDistance: CLLocationDistance? = nil,
    sliderValue: Double? = nil
  ) -> FuelReceiptParsedData {
    let lines = normalizeLines(recognizedLines)
    let fuelStation = extractFuelStation(from: lines)
    let amountPaid = extractAmountPaid(from: lines)
    let fuelVolume = extractFuelVolume(from: lines)
    let timestamp = extractTimestamp(from: lines) ?? Date()

    var parsed = FuelReceiptParsedData(
      fuelStation: fuelStation,
      amountPaid: amountPaid,
      fuelVolume: fuelVolume,
      timestamp: timestamp,
      rawLines: lines
    )
    
    parsed.verificationStatus = verifyFuelIntelligence(
      manualEntry: manualEntry,
      gpsDistance: gpsDistance,
      sliderValue: sliderValue,
      parsed: parsed
    )

    return parsed
  }
  
  private func verifyFuelIntelligence(
    manualEntry: ManualFuelEntry?,
    gpsDistance: CLLocationDistance?,
    sliderValue: Double?,
    parsed: FuelReceiptParsedData
  ) -> FuelIntelligenceVerificationStatus {
    guard manualEntry != nil || gpsDistance != nil || sliderValue != nil else {
      return .unverified(reason: "No verification data provided")
    }
    // 1. Cross-check with manual entry
    if let manual = manualEntry {
      // Allow slight variance (e.g. 2 liters or 5 currency units)
      if let vol = manual.volume, abs(vol - parsed.fuelVolume) > 2.0 {
        return .unverified(reason: "Extracted volume differs from manual entry")
      }
      if let cost = manual.cost, abs(cost - parsed.amountPaid) > 5.0 {
        return .unverified(reason: "Extracted cost differs from manual entry")
      }
    }

    // 2. Cross-check with GPS distance to ensure realistic fuel consumption
    if let distance = gpsDistance, distance > 0 {
      // Rough estimation: max 1.0 Liters per km for heavy trucks
      if parsed.fuelVolume > distance * 1.0 {
        return .unverified(reason: "Fuel volume is too high for the distance traveled")
      }
    }

    // 3. Cross-check with Fuel Slider
    if let slider = sliderValue {
      if slider < 0 || slider > 100 {
        return .unverified(reason: "Invalid fuel slider percentage")
      }
    }
    
    return .verified
  }

  private func normalizeLines(_ lines: [String]) -> [String] {
    let merged = lines.joined(separator: "\n")
      .replacingOccurrences(of: #"\r\n|\r"#, with: "\n", options: .regularExpression)

    return merged
      .split(separator: "\n")
      .map {
        $0
          .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .uppercased()
      }
      .filter { !$0.isEmpty }
  }

  private func extractFuelStation(from lines: [String]) -> String {
    let topLines = Array(lines.prefix(2))
    return topLines.joined(separator: ", ")
  }

  private func extractAmountPaid(from lines: [String]) -> Double {
    var candidates: [Double] = []

    for index in lines.indices {
      let line = lines[index]
      guard amountAnchors.contains(where: { line.contains($0) }) else { continue }

      candidates.append(contentsOf: decimals(from: line))
      if index + 1 < lines.count {
        candidates.append(contentsOf: decimals(from: lines[index + 1]))
      }
    }

    if let anchoredMax = candidates.max() {
      return anchoredMax
    }

    return lines
      .flatMap { decimals(from: $0) }
      .max() ?? 0
  }

  private func extractFuelVolume(from lines: [String]) -> Double {
    for index in lines.indices {
      let line = lines[index]
      guard volumeAnchors.contains(where: { line.contains($0) }) else { continue }
      guard !line.contains("RATE") else { continue }

      if let sameLine = decimals(from: line).first {
        return sameLine
      }

      if index + 1 < lines.count,
         let nextLine = decimals(from: lines[index + 1]).first {
        return nextLine
      }
    }

    return 0
  }

  private func extractTimestamp(from lines: [String]) -> Date? {
    var dateToken: String?
    var timeToken: String?

    for index in lines.indices {
      let line = lines[index]

      if dateToken == nil {
        dateToken = firstMatch(in: line, regex: dateRegex)
      }
      if timeToken == nil {
        timeToken = firstMatch(in: line, regex: timeRegex)
      }

      if let foundDate = dateToken, let foundTime = timeToken {
        return parseDateTime(date: foundDate, time: foundTime)
      }

      if let foundDate = firstMatch(in: line, regex: dateRegex), index + 1 < lines.count,
         let foundTime = firstMatch(in: lines[index + 1], regex: timeRegex) {
        return parseDateTime(date: foundDate, time: foundTime)
      }
    }

    if let foundDate = dateToken {
      return parseDateOnly(foundDate)
    }

    return nil
  }

  private func parseDateTime(date: String, time: String) -> Date? {
    let value = "\(date.replacingOccurrences(of: ".", with: "/")) \(time)"
    let formats = [
      "dd/MM/yyyy HH:mm", "dd/MM/yyyy HH:mm:ss",
      "dd-MM-yyyy HH:mm", "dd-MM-yyyy HH:mm:ss",
      "MM/dd/yyyy HH:mm", "MM/dd/yyyy HH:mm:ss",
      "dd/MM/yy HH:mm", "dd/MM/yy HH:mm:ss",
      "dd-MM-yy HH:mm", "dd-MM-yy HH:mm:ss",
      "dd/MMM/yyyy HH:mm", "dd/MMM/yyyy HH:mm:ss",
      "dd-MMM-yyyy HH:mm", "dd-MMM-yyyy HH:mm:ss",
      "dd/MMM/yyyy h:mm a", "dd/MMM/yyyy h:mm:ss a",
      "dd-MMM-yyyy h:mm a", "dd-MMM-yyyy h:mm:ss a",
      "dd/MMM/yy HH:mm", "dd/MMM/yy HH:mm:ss",
      "dd-MMM-yy HH:mm", "dd-MMM-yy HH:mm:ss",
      "dd/MMM/yy h:mm a", "dd/MMM/yy h:mm:ss a",
      "dd-MMM-yy h:mm a", "dd-MMM-yy h:mm:ss a"
    ]

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current

    for format in formats {
      formatter.dateFormat = format
      if let parsed = formatter.date(from: value) {
        return parsed
      }
    }

    return nil
  }

  private func parseDateOnly(_ date: String) -> Date? {
    let value = date.replacingOccurrences(of: ".", with: "/")
    let formats = [
      "dd/MM/yyyy", "dd-MM-yyyy", "MM/dd/yyyy",
      "dd/MM/yy", "dd-MM-yy",
      "dd/MMM/yyyy", "dd-MMM-yyyy", "dd/MMM/yy", "dd-MMM-yy"
    ]

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current

    for format in formats {
      formatter.dateFormat = format
      if let parsed = formatter.date(from: value) {
        return parsed
      }
    }

    return nil
  }

  private func decimals(from text: String) -> [Double] {
    guard let regex = decimalRegex else { return [] }
    let nsRange = NSRange(location: 0, length: text.utf16.count)

    return regex.matches(in: text, range: nsRange).compactMap { match in
      guard let range = Range(match.range, in: text) else { return nil }
      let normalized = text[range].replacingOccurrences(of: ",", with: ".")
      return Double(normalized)
    }
  }

  private func firstMatch(in text: String, regex: NSRegularExpression?) -> String? {
    guard let regex else { return nil }
    let range = NSRange(location: 0, length: text.utf16.count)
    guard let match = regex.firstMatch(in: text, range: range),
          let swiftRange = Range(match.range, in: text)
    else { return nil }
    return String(text[swiftRange])
  }
}
