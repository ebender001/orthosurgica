//
//  MeshCatalogManager.swift
//  CardioThoraxia
//

import Foundation
import Combine

@MainActor
final class MeshCatalogManager: ObservableObject {

    @Published var catalog: MeshCatalog?
    @Published var status: String = "Idle"
    @Published var error: String?

    private let service = MeshCatalogService()

    private enum Cache {
        private static let cachedFileName = "mesh_catalog.json"
        private static let cachedVersionKey = "mesh_catalog_cached_version"

        static func cachedVersion() -> String? {
            UserDefaults.standard.string(forKey: cachedVersionKey)
        }

        static func setCachedVersion(_ version: String?) {
            UserDefaults.standard.set(version, forKey: cachedVersionKey)
        }

        static func cachedFileURL() -> URL? {
            do {
                let dir = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                return dir.appendingPathComponent(cachedFileName)
            } catch {
                return nil
            }
        }

        static func loadCachedData() -> Data? {
            guard let url = cachedFileURL() else { return nil }
            return try? Data(contentsOf: url)
        }

        static func saveCachedData(_ data: Data, version: String?) {
            guard let url = cachedFileURL() else { return }
            do {
                try data.write(to: url, options: [.atomic])
                setCachedVersion(version)
            } catch {
                // Ignore cache write failures
            }
        }
    }

    func loadRemote() async {
        status = "Loading..."
        error = nil

        // 1) Try cache first for fast startup/offline support
        if catalog == nil, let cached = Cache.loadCachedData() {
            if let decoded = try? JSONDecoder().decode(MeshCatalog.self, from: cached) {
                catalog = decoded
                let v = Cache.cachedVersion() ?? ""
                status = v.isEmpty ? "Loaded cached" : "Loaded cached \(v)"
            }
        }

        // 2) Always fetch remote on launch (version + data)
        do {
            let (version, data) = try await service.fetchActiveCatalog()

            print("Downloaded catalog version:", version ?? "nil")
            print("Downloaded bytes:", data.count)

            // Preview helps catch HTML / error payloads / wrong JSON structure
            let preview = String(data: data, encoding: .utf8)
                .map { String($0.prefix(600)) } ?? "<non-utf8 data>"

            // If remote version matches cached version AND we already have a catalog loaded,
            // we can skip decoding/writing.
            if let v = version, v == Cache.cachedVersion(), catalog != nil {
                status = "Up to date \(v)"
                return
            }

            do {
                let decoded = try JSONDecoder().decode(MeshCatalog.self, from: data)
                catalog = decoded
                status = "Loaded remote \(version ?? "")"

                // Only cache if decoding succeeded
                Cache.saveCachedData(data, version: version)

            } catch let decodingError as DecodingError {
                let message: String
                switch decodingError {
                case .dataCorrupted(let ctx):
                    message = "dataCorrupted: \(ctx.debugDescription)"
                case .keyNotFound(let key, let ctx):
                    message = "keyNotFound: \(key.stringValue) – \(ctx.debugDescription)"
                case .typeMismatch(let type, let ctx):
                    message = "typeMismatch: \(type) – \(ctx.debugDescription)"
                case .valueNotFound(let type, let ctx):
                    message = "valueNotFound: \(type) – \(ctx.debugDescription)"
                @unknown default:
                    message = "unknown DecodingError"
                }

                self.error = "Decode failed (\(message)). Preview: \(preview)"
                self.status = "Failed"
            } catch {
                self.error = "Decode failed: \(error.localizedDescription). Preview: \(preview)"
                self.status = "Failed"
            }

        } catch {
            // Remote failed; keep cache if we have it
            if catalog != nil {
                status = "Offline (using cached catalog)"
            } else {
                self.error = error.localizedDescription
                status = "Failed"
            }
        }
    }
}
