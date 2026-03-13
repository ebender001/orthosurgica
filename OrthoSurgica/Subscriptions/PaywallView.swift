//
//  PaywallView.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 2/23/26.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subs: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("AI Insight helps summarize cardiothoracic literature from the abstract and metadata only.")
                        .foregroundStyle(.secondary)
                }

                if subs.isLoadingProducts {
                    Section { ProgressView("Loading…") }
                } else {
                    Section("Choose a plan") {
                        ForEach(subs.products) { product in
                            Button {
                                Task { await subs.purchase(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.displayName)
                                            .font(.headline)
                                        Text(product.description)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.headline)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section {
                        Button("Restore Purchases") {
                            Task { await subs.restorePurchases() }
                        }
                    }
                }

                if let msg = subs.lastErrorMessage {
                    Section {
                        Text(msg)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("AI Insight")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await subs.refreshProductsAndEntitlement() }
    }
}
