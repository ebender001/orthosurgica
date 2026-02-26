//
//  ProfessionalPaywallView.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 2/23/26.
//

import SwiftUI
import StoreKit

/// Option B: Academic with subtle premium styling.
/// Drop-in Paywall optimized for a cardiothoracic audience.
struct ProfessionalPaywallView: View {
    @EnvironmentObject private var subs: SubscriptionManager
    @Environment(\.dismiss) private var dismiss


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    header

                    plansSection

                    restoreSection

                    previewCard

                    valueBullets

                    footerTrust
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await subs.refreshProductsAndEntitlement()
            }
            .onChange(of: subs.hasActiveSubscription) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Insight")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Structured analysis of cardiothoracic literature.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {

                HStack(spacing: 10) {
                    Text("Preview")
                        .premiumEyebrow()

                    Text("What you’ll get")
                        .premiumSectionTitle()
                    Spacer()
                }

                Divider().opacity(0.6)

                PreviewSection(title: "One-Sentence Takeaway") {
                    Text("Preoperative renal function independently predicts early morbidity and mortality following aortic arch surgery.")
                }

                PreviewSection(title: "Practice Relevance") {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Likely")
                            .font(.body.weight(.semibold))
                        Spacer()
                        ConfidenceChip(level: .high)
                    }
                    Text("Supports perioperative risk stratification and planning.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var valueBullets: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Value")
                    .premiumEyebrow()

                Text("Built for clinical review and decision preparation")
                    .premiumSectionTitle()

                VStack(alignment: .leading, spacing: 10) {
                    ValueBullet(icon: "list.bullet.rectangle", title: "Structured summary", subtitle: "Study design, cohort, exposures, comparators, and outcomes.")
                    ValueBullet(icon: "checkmark.seal", title: "Evidence-anchored", subtitle: "Strictly limited to information reported in the abstract.")
                    ValueBullet(icon: "exclamationmark.triangle", title: "Limitations surfaced", subtitle: "Explicitly identifies missing data and abstract-level limitations.")
                    ValueBullet(icon: "stethoscope", title: "Practice relevance", subtitle: "Practice relevance assessment with defined confidence level.")
                }
            }
        }
    }

    private var plansSection: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Plans")
                    .premiumEyebrow()

                Text("Choose a plan")
                    .premiumSectionTitle()

                if subs.isLoadingProducts {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading plans…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if subs.products.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Plans are unavailable right now. Please try again.")
                            .foregroundStyle(.secondary)

                        Button("Reload") {
                            Task { await subs.refreshProductsAndEntitlement() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(spacing: 10) {
                        // Put annual first if it exists
                        ForEach(sortedPlans(subs.products)) { product in
                            PlanRow(
                                product: product,
                                isRecommended: isAnnual(product),
                                subtitle: planSubtitle(for: product)
                            ) {
                                Task { await subs.purchase(product) }
                            }
                        }
                    }
                }

                if let msg = subs.lastErrorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 6)
                }
            }
        }
    }

    private var restoreSection: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Account")
                    .premiumEyebrow()

                Button {
                    Task {
                        await subs.restorePurchases()
                        #if DEBUG
                        await subs.debugCurrentEntitlements()
                        await subs.debugLatestMonthly()
                        #endif
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Restore Purchases")
                        Spacer()
                    }
                    .font(.headline)
                }
                .buttonStyle(.borderless)
                .disabled(subs.isRestoring)

                Text("Restore access for subscriptions associated with this Apple ID.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Fully compliant, polished footer: auto-renew disclosures + cancellation + clinical disclaimer + Terms/Privacy links.
    private var footerTrust: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Your Apple ID account will be charged at confirmation of purchase and within 24 hours prior to renewal.")

            Text("Manage or cancel anytime in Apple ID subscriptions.")

            Text("AI Insight is generated from PubMed abstracts and metadata only and may contain omissions or inaccuracies. Verify against the abstract and full paper before changing practice. Clinical decisions should incorporate independent clinical judgement and patient-specific factors.")

            HStack(spacing: 16) {
                Spacer()
                Link("Terms of Use", destination: AppLinks.terms)
                Link("Privacy Policy", destination: AppLinks.privacy)
                Spacer()
            }
            .font(.footnote.weight(.semibold))
            .padding(.top, 2)
        }
        .font(.footnote)
        .lineSpacing(2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private func sortedPlans(_ products: [Product]) -> [Product] {
        // Keep annual first when possible, otherwise keep stable displayPrice sort
        products.sorted { a, b in
            if isAnnual(a) != isAnnual(b) { return isAnnual(a) }
            return a.displayPrice < b.displayPrice
        }
    }

    private func isAnnual(_ product: Product) -> Bool {
        // Heuristic: match by known product IDs if you want stronger logic.
        product.id.lowercased().contains("annual") || product.displayName.lowercased().contains("annual")
    }

    private func annualMonthlyEquivalent(for product: Product) -> String? {
        guard let sub = product.subscription else { return nil }
        // Only show for yearly products.
        guard sub.subscriptionPeriod.unit == .year else { return nil }

        let monthly = product.price / Decimal(12)

        // Use the product’s currency (StoreKit always provides one for the product).
        let currencyCode = product.priceFormatStyle.currencyCode

        let monthlyText = monthly.formatted(.currency(code: currencyCode))
        return "\(monthlyText)/mo billed annually"
    }

    private func planSubtitle(for product: Product) -> String {
        if isAnnual(product) {
            if let equiv = annualMonthlyEquivalent(for: product) {
                return "Best value • \(equiv)"
            }
            return "Best value for active clinicians"
        }
        return "Flexible access"
    }
}

// MARK: - Typography

private extension View {
    func premiumSectionTitle() -> some View {
        self
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.bottom, 2)
    }

    func premiumEyebrow() -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

// MARK: - Components

private struct PremiumCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
            )
    }
}

private struct PreviewSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .premiumEyebrow()
            content
                .font(.body)
                .lineSpacing(2)
        }
    }
}

private struct PreviewBullet: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
            Text(text)
        }
        .foregroundStyle(.secondary)
    }
}

private enum ConfidenceLevel { case low, moderate, high }

private struct ConfidenceChip: View {
    let level: ConfidenceLevel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption)
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(Capsule())
        .foregroundStyle(.secondary)
        .overlay(Capsule().strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1))
        .accessibilityLabel("Confidence \(label)")
    }

    private var label: String {
        switch level {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }
}

private struct ValueBullet: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlanRow: View {
    let product: Product
    let isRecommended: Bool
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)

                        if isRecommended {
                            Text("Best Value")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
                                )
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Start subscription purchase")
    }
}

private enum CalloutStyle { case info }

private struct CalloutPill: View {
    let icon: String
    let title: String
    let style: CalloutStyle

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
        )
    }
}
