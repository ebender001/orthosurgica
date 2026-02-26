//
//  SignInWithAppleView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 2/24/26.
//

import SwiftUI
import AuthenticationServices
import ParseSwift

struct SignInWithAppleView: View {
    var onSuccess: (_ identityToken: String, _ authorizationCode: String) -> Void
    var onCancel: () -> Void
    var onFailure: (_ error: Error) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sign in with Apple")
                    .font(.title2.weight(.semibold))

                Text("Sign in to continue generating AI insights across devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SignInWithAppleButton(.signIn) { request in
                    // Keep minimal. You can add `.fullName` / `.email` later if desired.
                    request.requestedScopes = []
                } onCompletion: { result in
                    Task { await handleAppleSignInResult(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(isWorking)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        switch result {
        case .failure(let error):
            if isCancelError(error) {
                onCancel()
                dismiss()
            } else {
                errorMessage = friendlyMessage(for: error)
                onFailure(error)
            }

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                let err = NSError(
                    domain: "SIWA",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Unexpected credential type."]
                )
                errorMessage = friendlyMessage(for: err)
                onFailure(err)
                return
            }

            let appleUserId = credential.user

            guard
                let tokenData = credential.identityToken,
                let codeData = credential.authorizationCode,
                let identityToken = String(data: tokenData, encoding: .utf8),
                let authorizationCode = String(data: codeData, encoding: .utf8),
                !identityToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                !authorizationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                let err = NSError(
                    domain: "SIWA",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing identity token or authorization code."]
                )
                errorMessage = friendlyMessage(for: err)
                onFailure(err)
                return
            }

            do {
                try await AuthenticationService.shared.signInWithApple(
                    appleUserId: appleUserId,
                    identityToken: identityToken
                )

                onSuccess(identityToken, authorizationCode)
                dismiss()
            } catch {
                errorMessage = friendlyMessage(for: error)
                onFailure(error)
            }
        }
    }

    private func isCancelError(_ error: Error) -> Bool {
        if let asError = error as? ASAuthorizationError {
            return asError.code == .canceled
        }
        let ns = error as NSError
        return ns.domain == ASAuthorizationError.errorDomain && ns.code == ASAuthorizationError.canceled.rawValue
    }

    private func friendlyMessage(for error: Error) -> String {
        if isCancelError(error) {
            return "Sign in was canceled."
        }
        return "Unable to sign in right now. Please try again."
    }
}
