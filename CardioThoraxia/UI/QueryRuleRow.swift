//
//  QueryRuleRow.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct QueryRuleRow: View {
    let rule: QueryRule

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        switch rule {
        case .mesh: return "Topic"
        case .keyword: return "Keyword"
        case .journal: return "Journal"
        case .author: return "Author"
        case .publicationType: return "Study Type"
        case .freeText: return "Advanced Search"
        }
    }

    private var subtitle: String {
        switch rule {
        case .mesh(let term, let major):
            return major ? "\(term) (Primary)" : term
        case .keyword(let term, let field):
            return "\(term) [\(field.rawValue)]"
        case .journal(let j):
            return j
        case .author(let a):
            return a
        case .publicationType(let pt):
            return pt
        case .freeText(let t):
            return t
        }
    }
}
