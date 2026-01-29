//
//  SearchResultsViewModel.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation
import Combine

@MainActor
final class SearchResultsViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(count: Int)
        case failed(String)
    }

    @Published var state: State = .idle
    @Published var articles: [Article] = []

    @Published var compiledTerm: String = ""
    @Published var totalCount: Int = 0
    @Published var isLoadingMore: Bool = false

    private let client: PubMedClient
    private var session: SearchSession?

    init(client: PubMedClient) {
        self.client = client
    }

    func run(query: QueryDefinition, retMax: Int = 20, isRefresh: Bool = false) async {
        // For an initial search, clear and show a full-screen loader.
        // For pull-to-refresh, keep current results visible.
        if !isRefresh {
            state = .loading
            articles = []
            session = nil
            totalCount = 0
        }

        compiledTerm = PubMedQueryCompiler.compile(query)
        isLoadingMore = false

        do {
            let (sess, _) = try await client.esearch(query: query, retStart: 0, retMax: retMax)
            session = sess
            totalCount = sess.totalCount

            let fetched = try await client.efetch(session: sess, retStart: 0, retMax: retMax)
            articles = fetched
            state = .loaded(count: fetched.count)
        } catch is CancellationError {
            // Swift task cancelled (normal). Keep whatever is currently on screen.
            state = articles.isEmpty ? .idle : .loaded(count: articles.count)

        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession cancelled (also normal). Keep whatever is currently on screen.
            state = articles.isEmpty ? .idle : .loaded(count: articles.count)

        } catch {
            totalCount = 0
            state = .failed(error.localizedDescription)
        }
    }

    func refresh(query: QueryDefinition, retMax: Int = 20) async {
        await run(query: query, retMax: retMax, isRefresh: true)
    }

    func loadMore(retMax: Int = 20) async {
        guard var sess = session else { return }
        guard !isLoadingMore else { return }

        if totalCount > 0, articles.count >= totalCount { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let start = sess.nextRetStart

        do {
            let more = try await client.efetch(session: sess, retStart: start, retMax: retMax)
            guard !more.isEmpty else { return }

            articles.append(contentsOf: more)

            // Advance cursor for next page
            sess = SearchSession(
                webEnv: sess.webEnv,
                queryKey: sess.queryKey,
                totalCount: sess.totalCount,
                nextRetStart: start + retMax,
                createdAt: sess.createdAt
            )
            session = sess

            state = .loaded(count: articles.count)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
