//
//  AdvancedSearchEntryView.swift
//  OrthoSurgica
//
//  Created by Edward Bender on 1/29/26.
//

import SwiftUI

struct AdvancedSearchEntryView: View {

    enum Mode: String, CaseIterable, Identifiable {
        case appendClause
        case editFullQuery

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appendClause: return "Add clause"
            case .editFullQuery: return "Edit full query"
            }
        }
    }

    struct Result {
        let mode: Mode
        let text: String
    }

    let baseQuery: String
    let onSave: (Result) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .appendClause
    @State private var text: String = ""

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .appendClause {
                    Text("Add extra PubMed search syntax to narrow or broaden results. It will be combined with your selected topics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Power users can edit the full PubMed query string. Saving will replace your selected topics with this custom query.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if mode == .appendClause {
                Section("Current query") {
                    Text(baseQuery)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Section("Add clause") {
                    TextField("e.g. randomized[tiab] OR meta-analysis[pt]", text: $text, axis: .vertical)
                        .lineLimit(3...8)

                    Text("Tip: you can use PubMed tags like [tiab], [pt], [jour], [au], date ranges, and parentheses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Edit full query") {
                    TextField("PubMed query", text: $text, axis: .vertical)
                        .lineLimit(6...14)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("Start from the auto-generated query below and edit as needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(baseQuery)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .navigationTitle("Advanced Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(Result(mode: mode, text: trimmed))
                    dismiss()
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            // Prefill only when editing full query; keep append mode empty.
            if mode == .editFullQuery {
                text = baseQuery
            }
        }
        .onChange(of: mode) { _, newMode in
            // Switching modes should set sensible defaults.
            switch newMode {
            case .appendClause:
                text = ""
            case .editFullQuery:
                text = baseQuery
            }
        }
    }
}

