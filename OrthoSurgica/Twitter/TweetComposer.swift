//
//  TweetComposer.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/8/26.
//

import Foundation

struct TweetComposer {
    static func compose(
        title: String,
        journal: String? = nil,
        year: String? = nil,
        takeaway: String? = nil,
        url: URL? = nil,
        hashtags: [String] = ["CTSurgery"]
    ) -> String {
        // Normalize hashtags
        let tagString: String = hashtags
            .map { $0.hasPrefix("#") ? $0 : "#\($0)" }
            .joined(separator: " ")

        // Base pieces (order matters)
        var parts: [String] = []
        parts.append("🫀 \(title.trimmingCharacters(in: .whitespacesAndNewlines))")

        var meta: [String] = []
        if let journal, !journal.isEmpty { meta.append(journal) }
        if let year, !year.isEmpty { meta.append(year) }
        if !meta.isEmpty { parts.append("(\(meta.joined(separator: ", ")))") }

        if let takeaway, !takeaway.isEmpty {
            parts.append("Key point: \(takeaway.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if let url { parts.append(url.absoluteString) }
        if !tagString.isEmpty { parts.append(tagString) }

        // Join, then trim if needed
        var tweet = parts.joined(separator: " ")

        // Hard cap (X limit is 280; links are “counted” differently on X,
        // but for share-sheet text, we just keep it simple and safe).
        let maxChars = 280
        if tweet.count > maxChars {
            // Trim title first, then takeaway.
            tweet = smartTrim(tweet: tweet, maxChars: maxChars)
        }

        return tweet
    }

    private static func smartTrim(tweet: String, maxChars: Int) -> String {
        if tweet.count <= maxChars { return tweet }

        // Strategy: if there's “Key point: …” try trimming that section first.
        // Otherwise just truncate with ellipsis.
        let keyPointMarker = " Key point: "
        if let range = tweet.range(of: keyPointMarker) {
            // Remove takeaway entirely if needed
            var withoutTakeaway = tweet
            // Remove from marker up to next " http" or " #" if present
            let afterMarker = range.upperBound
            let tail = withoutTakeaway[afterMarker...]

            let splitPoints: [String] = [" http", " #"]
            if let cut = splitPoints.compactMap({ tail.range(of: $0) }).min(by: { $0.lowerBound < $1.lowerBound }) {
                // Remove takeaway text only
                withoutTakeaway.removeSubrange(afterMarker..<cut.lowerBound)
            } else {
                // Remove everything after marker
                withoutTakeaway.removeSubrange(afterMarker..<withoutTakeaway.endIndex)
            }

            // Clean double spaces
            let cleaned = withoutTakeaway.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count <= maxChars { return cleaned }
        }

        // Fallback: truncate with ellipsis
        let ellipsis = "…"
        let allowed = max(0, maxChars - ellipsis.count)
        return String(tweet.prefix(allowed)) + ellipsis
    }
}
