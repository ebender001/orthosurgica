//
//  TweetButton.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/8/26.
//

import SwiftUI

struct TweetButton: View {
    let title: String
    let journal: String?
    let year: String?
    let takeaway: String?
    let url: URL?

    @State private var showingShare = false
    @State private var shareItems: [Any] = []

    var body: some View {
        Button {
            let tweetText = TweetComposer.compose(
                title: title,
                journal: journal,
                year: year,
                takeaway: takeaway,
                url: url,
                hashtags: ["CTSurgery", "CardioThoracicSurgery"]
            )

            // Share sheet works best when text + URL are separate items (if URL exists)
            var items: [Any] = [tweetText]
            if let url { items.append(url) }
            shareItems = items
            showingShare = true
        } label: {
            Label("Tweet", systemImage: "paperplane")
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(items: shareItems)
        }
    }
}
