//
//  AuthenticationService.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/24/26.
//

import Foundation
import ParseSwift

@MainActor
final class AuthenticationService {
    static let shared = AuthenticationService()
    private init() {}

    enum AuthError: LocalizedError {
        case missingAppleUserId
        case missingIdentityToken

        var errorDescription: String? {
            switch self {
            case .missingAppleUserId: return "Missing Apple user identifier."
            case .missingIdentityToken: return "Missing Apple identity token."
            }
        }
    }

    /// Logs in (or signs up) a Parse user using Sign in with Apple tokens.
    func signInWithApple(appleUserId: String, identityToken: String) async throws {
        let userId = appleUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = identityToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !userId.isEmpty else { throw AuthError.missingAppleUserId }
        guard !token.isEmpty else { throw AuthError.missingIdentityToken }

        let provider = "apple"
        let appleAuth: [String: String] = [
            "id": userId,
            "token": token
        ]

        do {
            _ = try await User.login(provider, authData: appleAuth)
        } catch {
            #if DEBUG
            print("Parse Apple login failed:", error)
            #endif
            throw error
        }
    }
}
