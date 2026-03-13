//
//  MeshCatalogLoader.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation

// MARK: - Models

public struct MeshTerm: Codable, Hashable {
    public let term: String
    public let majorTopicDefault: Bool
}

public typealias MeshCatalog = [String: [String: [String: [MeshTerm]]]]
// Major Heading -> Subspecialty -> Topic Group -> Terms


// MARK: - Loader

public enum MeshCatalogLoader {

    public enum LoadError: Error, LocalizedError {
        case resourceNotFound(String)
        case decodeFailed

        public var errorDescription: String? {
            switch self {
            case .resourceNotFound(let name):
                return "Could not find \(name) in the app bundle."
            case .decodeFailed:
                return "Failed to decode MeshCatalog JSON."
            }
        }
    }

    /// Load MeshCatalog from the app bundle.
    public static func load(
        name: String = "MeshCatalog.v1",
        ext: String = "json",
        bundle: Bundle = .main
    ) throws -> MeshCatalog {

        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw LoadError.resourceNotFound("\(name).\(ext)")
        }

        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(MeshCatalog.self, from: data)
        } catch {
            throw LoadError.decodeFailed
        }
    }
}


// MARK: - Convenience accessors (optional but handy)

public extension MeshCatalog {
    var majorHeadingsSorted: [String] {
        keys.sorted()
    }

    func subspecialtiesSorted(for majorHeading: String) -> [String] {
        self[majorHeading]?.keys.sorted() ?? []
    }

    func topicGroupsSorted(for majorHeading: String, subspecialty: String) -> [String] {
        self[majorHeading]?[subspecialty]?.keys.sorted() ?? []
    }

    func terms(for majorHeading: String, subspecialty: String, topicGroup: String) -> [MeshTerm] {
        self[majorHeading]?[subspecialty]?[topicGroup] ?? []
    }
}
