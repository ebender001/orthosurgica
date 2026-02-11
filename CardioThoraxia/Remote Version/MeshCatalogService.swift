//
//  MeshCatalogService.swift
//  CardioThoraxia
//

import Foundation
import ParseSwift

enum MeshCatalogServiceError: Error, LocalizedError {
    case noActiveRow
    case missingFile
    case missingFileData

    var errorDescription: String? {
        switch self {
        case .noActiveRow:
            return "No active MeshCatalog row found."
        case .missingFile:
            return "Active MeshCatalog row is missing its JSON file."
        case .missingFileData:
            return "Failed to download JSON file data."
        }
    }
}

final class MeshCatalogService {

    func fetchActiveCatalog() async throws -> (version: String?, data: Data) {

        let query = MeshCatalogParse.query("isActive" == true).limit(1)
        let results = try await query.find()

        guard let active = results.first else {
            throw MeshCatalogServiceError.noActiveRow
        }

        guard let file = active.json else {
            throw MeshCatalogServiceError.missingFile
        }

        // Fetch file metadata + ensure it downloads
        let fetchedFile = try await file.fetch()

        // Preferred: read from local disk
        if let localURL = fetchedFile.localURL {
            let data = try Data(contentsOf: localURL)
            return (active.version, data)
        }

        // Fallback: direct URL download
        if let remoteURL = fetchedFile.url {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            return (active.version, data)
        }

        throw MeshCatalogServiceError.missingFileData
    }
}
