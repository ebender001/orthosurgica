//
//  TypeBadge.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/14/26.
//

import SwiftUI

struct TypeBadge: View {
    let kind: ArticleKind

    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().fill(kind.tint.opacity(0.18)))
            .overlay(Circle().strokeBorder(kind.tint.opacity(0.25), lineWidth: 1))
            .frame(width: 16, height: 16)
            .shadow(radius: 1, y: 1)
            .accessibilityLabel(kind.accessibilityLabel)
    }
}
