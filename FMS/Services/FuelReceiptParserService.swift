import Foundation

struct FuelReceiptParserService {
  private let dateRegex = try? NSRegularExpression(pattern: #"\b\d{2}[-/.]\d{2}[-/.]\d{2,4}\b"#)
  private let timeRegex = try? NSRegularExpression(pattern: #"\b\d{2}:\d{2}(?::\d{2})?\b"#)
  private let decimalRegex = try? NSRegularExpression(pattern: #"\b\d+(?:[.,]\d{1,3})\b"#)

  private let amountAnchors = ["TOTAL", "AMOUNT"]
  private let volumeAnchors = ["LTR", "LITERS", "LITRES", "LITER", "VOL", "VOLUME"]

  func parse(recognizedLines: [String]) -> FuelReceiptParsedData {
    let lines = normalizeLines(recognizedLines)
    let fuelStation = extractFuelStation(from: lines)
    let amountPaid = extractAmountPaid(from: lines)
    let fuelVolume = extractFuelVolume(from: lines)
    let timestamp = extractTimestamp(from: lines) ?? Date()

    return FuelReceiptParsedData(
      fuelStation: fuelStation,
      amountPaid: amountPaid,
      fuelVolume: fuelVolume,
      timestamp: timestamp,
      rawLines: lines
    )
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
      "dd-MM-yy HH:mm", "dd-MM-yy HH:mm:ss"
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
    let formats = ["dd/MM/yyyy", "dd-MM-yyyy", "MM/dd/yyyy", "dd/MM/yy", "dd-MM-yy"]

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
