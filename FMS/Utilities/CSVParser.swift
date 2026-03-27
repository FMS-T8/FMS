//
//  CSVParser.swift
//  FMS
//
//  Created by Anish on 26/03/26.
//

import Foundation

public struct CSVParser {
    
    public enum CSVError: LocalizedError {
        case fileReadFailed
        case emptyFile
        case invalidFormat
        
        public var errorDescription: String? {
            switch self {
            case .fileReadFailed: return "Could not read the selected file. Please ensure it is a valid CSV."
            case .emptyFile: return "The CSV file is empty."
            case .invalidFormat: return "The CSV format is invalid or missing headers."
            }
        }
    }
    
    /// Parses a local CSV file URL into an array of dictionaries mapping Header -> Value.
    public static func parse(url: URL) throws -> [[String: String]] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw CSVError.fileReadFailed
        }
        
        // Clean up carriage returns and split into lines
        let lines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard let headerLine = lines.first else {
            throw CSVError.emptyFile
        }
        
        // Extract headers
        let headers = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard !headers.isEmpty else {
            throw CSVError.invalidFormat
        }
        
        var result: [[String: String]] = []
        
        // Parse rows
        for line in lines.dropFirst() {
            let values = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            var row: [String: String] = [:]
            
            for (index, header) in headers.enumerated() {
                if index < values.count {
                    let val = values[index]
                    row[header] = val.isEmpty ? nil : val
                }
            }
            result.append(row)
        }
        
        return result
    }
}
