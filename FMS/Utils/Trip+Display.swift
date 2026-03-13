import Foundation

extension Trip {
    var routeTexts: (startText: String, endText: String) {
        let start = startName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let end = endName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let startText = start.isEmpty ? "Start" : start
        let endText = end.isEmpty ? "End" : end
        return (startText, endText)
    }
    
    var displayRoute: String {
        let texts = routeTexts
        let start = texts.startText.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = texts.endText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !start.isEmpty && !end.isEmpty {
            return "\(texts.startText) to \(texts.endText)"
        }
        return "Trip"
    }
    
    var displayTitle: String {
        let shipment = shipmentDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !shipment.isEmpty { return shipment }
        return displayRoute
    }
}
