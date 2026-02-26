//
//  ArticleDetailView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI
import StoreKit
import ParseSwift

// MARK: - AI Insight UI

struct ArticleDetailView: View {
    let article: Article
    let timeoutNanoseconds: UInt64 = 10_000_000_000 // 10 seconds

    private struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }
    
    @StateObject private var aiVM = ArticleAIViewModel()
    @EnvironmentObject private var subs: SubscriptionManager

    @State private var showingPaywall = false
    @State private var showingAIInsightSheet = false
    @State private var sharePayload: SharePayload?
    @State private var didAttemptAIGeneration = false
    @State private var showingSIWA = false
    @State private var authErrorMessage: String?
    @State private var isSigningIn = false
    @State private var showSlowLoadingHint = false
    
    @Environment(\.colorScheme) private var colorScheme

    private var pubmedURL: URL {
        URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(article.id)/")!
    }

    private var badgeTintOpacity: Double { colorScheme == .dark ? 0.28 : 0.14 }
    private var badgeStrokeOpacity: Double { colorScheme == .dark ? 0.32 : 0.25 }

    private func scholarlyTitleCase(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return input }

        // Words typically lowercased in scholarly/AMA-style title case unless first/last.
        let minorWords: Set<String> = [
            "a","an","and","as","at","but","by","for","from","in","nor","of","on","or","per","the","to","via","with","without"
        ]

        // Split on spaces while preserving simple punctuation inside tokens.
        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !parts.isEmpty else { return trimmed }

        func capitalizeToken(_ token: String) -> String {
            // If token contains letters, capitalize first letter and lowercase the rest.
            // Preserve leading/trailing punctuation.
            let leadingSub = token.prefix { !$0.isLetter && !$0.isNumber }
            let trailingSub = token.reversed().prefix { !$0.isLetter && !$0.isNumber }.reversed()
            let leading = String(leadingSub)
            let trailing = String(trailingSub)
            let coreStart = token.index(token.startIndex, offsetBy: leading.count)
            let coreEnd = token.index(token.endIndex, offsetBy: -trailing.count)
            let core = coreStart <= coreEnd ? String(token[coreStart..<coreEnd]) : ""

            guard !core.isEmpty else { return token }

            // Handle hyphenated words: "endovascular-therapy" => "Endovascular-Therapy"
            let hyphenated = core.split(separator: "-", omittingEmptySubsequences: false).map { part -> String in
                let s = String(part)
                guard let first = s.first else { return s }
                return String(first).uppercased() + s.dropFirst().lowercased()
            }.joined(separator: "-")

            return "\(leading)\(hyphenated)\(trailing)"
        }

        var output: [String] = []

        for (idx, token) in parts.enumerated() {

            // Keep all-caps abbreviations (e.g., "JAMA", "CTS") as-is.
            let letters = token.filter { $0.isLetter }
            let isAllCapsAbbrev = !letters.isEmpty && letters == letters.uppercased() && letters.count <= 6

            if isAllCapsAbbrev {
                output.append(token)
                continue
            }

            let isFirst = idx == 0
            let isLast = idx == parts.count - 1

            // Compare minor-word status on the core token (strip punctuation for check).
            let coreLower = token.trimmingCharacters(in: CharacterSet.punctuationCharacters).lowercased()

            if !isFirst && !isLast && minorWords.contains(coreLower) {
                // Lowercase minor words, preserve punctuation.
                // Simple approach: lowercase the whole token except keep punctuation as-is.
                // Then capitalize if the token is something like "of," => "of,"
                output.append(token.lowercased())
            } else {
                output.append(capitalizeToken(token))
            }
        }

        return output.joined(separator: " ")
    }

    private var tweetText: String {
        // Keep it simple and reliable; you can expand later with AI takeaways, hashtags, etc.
        var parts: [String] = []
        parts.append("🫀 \(article.title)")
        if let journal = article.journal, !journal.isEmpty {
            parts.append("(\(journal))")
        }
        parts.append(pubmedURL.absoluteString)
        parts.append("#CTSurgery")

        var tweet = parts.joined(separator: " ")
        // Safety cap for share text (simple truncation)
        if tweet.count > 280 {
            tweet = String(tweet.prefix(279)) + "…"
        }
        return tweet
    }

    private var authorsDisplayText: String? {
        guard !article.authors.isEmpty else { return nil }
        if article.authors.count > 4 {
            let firstFour = article.authors.prefix(4).joined(separator: ", ")
            return firstFour + ", et al."
        } else {
            return article.authors.joined(separator: ", ")
        }
    }

    // MARK: - Extracted subviews (helps the compiler type-check SwiftUI)

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle().fill(article.kind.tint.opacity(badgeTintOpacity))
                    )
                    .overlay(
                        Circle().strokeBorder(article.kind.tint.opacity(badgeStrokeOpacity), lineWidth: 1)
                    )
                    .frame(width: 18, height: 18)
                    .shadow(radius: 1, y: 1)
                    .padding(.top, 4)
                    .accessibilityLabel(article.kind.accessibilityLabel)

                Text(article.title)
                    .font(.title3)
                    .bold()
            }

            if let journal = article.journal, !journal.isEmpty {
                let cleanJournal = journal.split(separator: ":").first.map(String.init) ?? journal
                let formattedJournal = scholarlyTitleCase(cleanJournal)

                Text(formattedJournal)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if let authorsText = authorsDisplayText {
                Text(authorsText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let year = article.year {
                let yearText = year.formatted(.number.grouping(.never))
                if let month = article.month, !month.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("\(month) \(yearText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(yearText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var abstractSection: some View {
        if let abstract = article.abstractText, !abstract.isEmpty {
            Divider()

            Text("Abstract")
                .font(.headline)

            Button {
                // Drive behavior from CTA state.
                switch aiVM.ctaState {
                case .needsSubscription:
                    showingPaywall = true
                case .needsSignIn:
                    // Phase 2: present Sign in with Apple.
                    showingSIWA = true
                case .loading:
                    break
                case .freeRemaining, .subscribed:
                    didAttemptAIGeneration = true
                    Task { await aiVM.generate(for: article) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.hierarchical)

                    Text(aiVM.isLoading ? "Generating AI Insight…" : aiVM.ctaState.buttonTitle)

                    Spacer(minLength: 0)

                    if aiVM.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(aiVM.isLoading || aiVM.insight != nil || !aiVM.ctaState.isButtonEnabled)
            .buttonStyle(.bordered)
            .tint(.accentColor)
            .accessibilityHint("Generate a structured interpretation of this abstract")

            if aiVM.isLoading {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating AI Insight from the abstract…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if showSlowLoadingHint {
                        Text("Still working… PubMed abstracts can be dense.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 2)
                .transition(.opacity)
            }

            if let helper = aiVM.ctaState.helperText {
                Text(helper)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            if let authErrorMessage {
                Text(authErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let msg = aiVM.errorMessage,
               aiVM.ctaState != .needsSignIn,
               aiVM.ctaState != .needsSubscription {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            // Keep layout stable: show a skeleton card while generating.
            if aiVM.isLoading, aiVM.insight == nil {
                SkeletonTakeawayCard()
                    .padding(.top, 4)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.22), value: aiVM.isLoading)
            }

            if let insight = aiVM.insight {
                TakeawayCard(insight: insight) {
                    showingAIInsightSheet = true
                }
                .padding(.top, 4)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.22), value: aiVM.insight != nil)
            }

            Text(abstract)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        Divider()
        Link("View on PubMed", destination: pubmedURL)
    }

    // MARK: - Body pieces (keeps SwiftUI type-check fast)

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerSection
                abstractSection
                footerSection
            }
            .padding()
        }
    }

    private var shareToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                sharePayload = SharePayload(items: [tweetText, pubmedURL])
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share")
        }
    }

    private var siwaSheet: some View {
        SignInWithAppleView(
            onSuccess: { identityToken, authorizationCode in
                Task {
                    await handleSIWASuccess(identityToken: identityToken,
                                            authorizationCode: authorizationCode)
                }
            },
            onCancel: {
                // optional: no-op or analytics
            },
            onFailure: { error in
                // optional: log/analytics
                authErrorMessage = error.localizedDescription
            }
        )
    }

    private var paywallSheet: some View {
        ProfessionalPaywallView()
            .environmentObject(subs)
    }

    var body: some View {
        mainContent
            .onAppear {
                aiVM.updateEntitlement(subs.entitlement)

                let signedIn = (User.current != nil) && ((User.current?.sessionToken?.isEmpty == false))
                aiVM.updateQuota(guestRemaining: nil, userRemaining: nil, isSignedIn: signedIn)

                if !signedIn {
                    Task { await aiVM.refreshGuestQuota() }
                }
            }
            .onChange(of: subs.entitlement) { _, newValue in
                aiVM.updateEntitlement(newValue)
            }
            .onChange(of: aiVM.insight != nil) { _, hasInsight in
                if hasInsight { didAttemptAIGeneration = false }
            }
            .onChange(of: aiVM.ctaState) { _, newValue in
                guard didAttemptAIGeneration else { return }
                if newValue == .needsSignIn {
                    showingSIWA = true
                    didAttemptAIGeneration = false
                } else if newValue == .needsSubscription {
                    showingPaywall = true
                    didAttemptAIGeneration = false
                }
            }
            .onChange(of: aiVM.isLoading) { _, isLoading in
                handleLoadingChange(isLoading)
            }
            .navigationTitle("Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { shareToolbar }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            .sheet(isPresented: $showingSIWA) {
                siwaSheet
            }
            .sheet(isPresented: $showingPaywall) {
                paywallSheet
            }
            .sheet(isPresented: $showingAIInsightSheet) {
                if let insight = aiVM.insight {
                    AIInsightSheetView(insight: insight)
                }
            }
    }

    @MainActor
    private func handleLoadingChange(_ isLoading: Bool) {
        if isLoading {
            showSlowLoadingHint = false

            // Run delay off-main, then hop back to MainActor to mutate state.
            Task {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                await MainActor.run {
                    guard aiVM.isLoading else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSlowLoadingHint = true
                    }
                }
            }
        } else {
            showSlowLoadingHint = false
        }
    }
    
    @MainActor
    private func handleSIWASuccess(identityToken: String, authorizationCode: String) async {
        // SignInWithAppleView already authenticated with Parse via AuthenticationService.
        // Here we just update UI state.

        guard !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }

        // Clear any prior auth error.
        authErrorMessage = nil

        // Derive signed-in state from Parse (source of truth).
        let signedIn = (User.current != nil) && ((User.current?.sessionToken?.isEmpty == false))

        // Signed-in users have no additional freebies in your Phase 2.
        aiVM.updateQuota(
            guestRemaining: aiVM.quota.guestRemaining,
            userRemaining: 0,
            isSignedIn: signedIn
        )

        // Close the SIWA sheet.
        showingSIWA = false

        // Refresh StoreKit entitlement so we can route correctly.
        await subs.refreshEntitlement()

        // If they are already subscribed, let them generate without interrupting.
        // Otherwise, send them to the paywall.
        if subs.entitlement.isActive {
            showingPaywall = false
        } else {
            showingPaywall = true
        }
    }
}

// MARK: - Skeleton Takeaway (placeholder while generating)

private struct SkeletonTakeawayCard: View {
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .padding(.top, 1)
                .opacity(0.65)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("AI Takeaway")
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 8)

                    // Chip placeholder
                    Text("Confidence")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                }

                // Placeholder lines
                VStack(alignment: .leading, spacing: 6) {
                    Text("Generating a one-sentence takeaway")
                    Text("This may take a few seconds")
                }
                .font(.body)

                HStack(spacing: 6) {
                    Text("Tap for full insight")
                    Image(systemName: "chevron.up.chevron.down")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.10), lineWidth: 1)
        )
        .redacted(reason: .placeholder)
        // Subtle motion so it feels alive without being flashy.
        .shimmering(active: true)
        .accessibilityHidden(true)
    }
}

// MARK: - Takeaway Card

private struct TakeawayCard: View {
    let insight: AIInsight
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("AI Takeaway")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)

                        ConfidenceBadge(confidence: insight.should_change_practice.confidence)
                    }

                    Text(insight.one_sentence_takeaway)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text("Tap for full insight")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI Takeaway")
        .accessibilityHint("Opens a structured AI insight sheet")
    }
}

private struct ConfidenceBadge: View {
    let confidence: String

    private var symbolName: String {
        switch confidence {
        case "High": return "checkmark.seal.fill"
        case "Moderate": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var labelText: String {
        confidence.isEmpty ? "Confidence" : "\(confidence)"
    }

    var body: some View {
        Label {
            Text(labelText)
        } icon: {
            Image(systemName: symbolName)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .accessibilityLabel("Confidence \(labelText)")
    }
}

// MARK: - AI Insight Sheet

private struct AIInsightSheetView: View {
    let insight: AIInsight

    @Environment(\.dismiss) private var dismiss

    private var friendlyGeneratedText: String? {
        guard let iso = insight.generated_at, !iso.isEmpty else { return nil }

        // Try ISO-8601 first
        if let date = ISO8601DateFormatter().date(from: iso) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        // Fallback: attempt without fractional seconds (common variant)
        let noFractional = iso.replacingOccurrences(of: "\\.\\d+Z$", with: "Z", options: .regularExpression)
        if let date = ISO8601DateFormatter().date(from: noFractional) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        // If parsing fails, return the raw value
        return iso
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionCard(title: "Disclaimer") {
                        Text("AI Insight is generated from the PubMed abstract and metadata only (not full text). It may contain omissions or inaccuracies. Please verify against the abstract and full paper before changing practice. Clinical decisions should always incorporate independent clinical judgment and patient-specific factors.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(insight.source_scope)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    SectionCard(title: "One-Sentence Takeaway") {
                        Text(insight.one_sentence_takeaway)
                            .font(.body)
                            .textSelection(.enabled)
                    }

                    SectionCard(title: "Study Snapshot") {
                        KeyValueRow(label: "Study type", value: insight.study_type)
                        KeyValueRow(label: "Population", value: insight.population)
                        KeyValueRow(label: "Intervention / Exposure", value: insight.intervention_or_exposure)
                        KeyValueRow(label: "Comparator", value: insight.comparator)
                    }

                    SectionCard(title: "Outcomes Reported") {
                        BulletList(items: insight.outcomes_reported)
                    }

                    SectionCard(title: "Key Findings") {
                        BulletList(items: insight.key_findings)
                    }

                    SectionCard(title: "Limitations") {
                        BulletList(items: insight.limitations)
                    }

                    SectionCard(title: "CT Surgery Implications") {
                        BulletList(items: insight.ct_surgery_implications)
                    }

                    SectionCard(title: "Should This Change Practice?") {
                        KeyValueRow(label: "Conclusion", value: insight.should_change_practice.conclusion)
                        KeyValueRow(label: "Confidence", value: insight.should_change_practice.confidence)
                        Text("Rationale")
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 8)
                        BulletList(items: insight.should_change_practice.rationale)
                    }

                    SectionCard(title: "Evidence Notes") {
                        BulletList(items: insight.evidence_notes)
                    }

                    // About this insight (scope + friendly timestamp; technical details optional)
                    SectionCard(title: "About this insight") {
                        KeyValueRow(label: "Scope", value: insight.source_scope)

                        if let generated = friendlyGeneratedText {
                            KeyValueRow(label: "Generated", value: generated)
                        }

                        if insight.model != nil || insight.prompt_version != nil {
                            DisclosureGroup("Technical details") {
                                VStack(alignment: .leading, spacing: 10) {
                                    if let model = insight.model {
                                        KeyValueRow(label: "AI model", value: model)
                                    }
                                    if let ver = insight.prompt_version {
                                        KeyValueRow(label: "Prompt version", value: String(ver))
                                    }
                                }
                                .padding(.top, 6)
                            }
                            .font(.subheadline)
                            .padding(.top, 6)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("AI Insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.10), lineWidth: 1)
        )
    }
}

private struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BulletList: View {
    let items: [String]

    var body: some View {
        if items.isEmpty {
            Text("Not reported in abstract.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .font(.body.weight(.semibold))
                        Text(items[idx])
                            .font(.body)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}


// MARK: - Lightweight shimmer (no dependencies)

private extension View {
    func shimmering(active: Bool) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

private struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -0.7

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        Color.primary.opacity(0.10),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .rotationEffect(.degrees(20))
                            .offset(x: geo.size.width * phase)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                            .onAppear {
                                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                                    phase = 0.7
                                }
                            }
                    }
                }
            }
    }
}
