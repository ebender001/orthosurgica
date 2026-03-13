//
//  PubMedAppConfig.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/29/26.
//
import Foundation

enum PubMedAppConfig {
    static var apiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "PUBMED_API_KEY") as? String
    }

    static var tool: String? {
        Bundle.main.object(forInfoDictionaryKey: "PUBMED_TOOL_NAME") as? String
    }

    static var email: String? {
        Bundle.main.object(forInfoDictionaryKey: "PUBMED_CONTACT_EMAIL") as? String
    }
}

enum AppBranding {
    private static let fallbackDisplayName = "OrthoSurgica"
    private static let fallbackCatalogName = "MeshCatalog.v1"

    static var displayName: String {
        configuredString(for: "CFBundleDisplayName")
            ?? configuredString(for: "CFBundleName")
            ?? fallbackDisplayName
    }

    static var bundledMeshCatalogName: String {
        configuredString(for: "BUNDLED_MESH_CATALOG_NAME") ?? fallbackCatalogName
    }

    static var meshCatalogCacheNamespace: String {
        let rawNamespace = "\(displayName)_\(bundledMeshCatalogName)"
        let scalars = rawNamespace.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "_"
        }
        let namespace = String(scalars)
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return namespace.isEmpty ? "mesh_catalog" : namespace.lowercased()
    }

    static var deleteAccountDescription: String {
        "Permanently delete your \(displayName) account and associated data. This action cannot be undone."
    }

    private static func configuredString(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty, !trimmedValue.hasPrefix("$(") else {
            return nil
        }

        return trimmedValue
    }
}
