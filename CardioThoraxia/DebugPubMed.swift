//
//  DebugPubMed.swift
//  CardioThoraxia
//
//  Created by Edward Bender on 1/29/26.
//

import Foundation
import SwiftData

func runMitralValveRepairESearch() {
    Task {
        do {
            let client = PubMedClient()
            await client.updateConfig { cfg in
                cfg.tool = "CardioThoraxia"
                cfg.email = "you@example.com"   // optional but recommended
                cfg.apiKey = PubMedAppConfig.apiKey
                cfg.tool = PubMedAppConfig.tool
                cfg.email = PubMedAppConfig.email
            }

            let q = QueryDefinition.andGroup(
                [
                    .mesh(term: "Mitral Valve", majorTopic: true),
                    .keyword(term: "repair", field: .titleAbstract)
                ],
                filters: QueryFilters(date: .lastDays(365), humansOnly: true, englishOnly: true)
            )

            let (session, pmids) = try await client.esearch(query: q, sort: .pubDate, retStart: 0, retMax: 20)
            
            let articles = try await client.efetch(session: session, retStart: 0, retMax: 20)
            print("TERM:", PubMedQueryCompiler.compile(q))
            print("Fetched articles: ", articles.count)
            if let first = articles.first {
                print("First title: ", first.title)
                print("Journal: ", first.journal ?? "nil", "Year: ", first.year ?? 0)
                print("DOI: ", first.doi ?? "nil")
                print("Abstract: ", (first.abstractText ?? "nil").prefix(250))
            }

//            print("Total:", session.totalCount)
//            print("PMIDs:", pmids)
//            print("WebEnv:", session.webEnv)
//            print("QueryKey:", session.queryKey)

        } catch {
            print("ESearch failed:", error)
        }
    }
}

@MainActor
func seedMitralFeedIfMissing(context: ModelContext) throws -> UUID {
    // Look for existing
    let desc = FetchDescriptor<FeedRecord>(predicate: #Predicate { $0.title == "Mitral Valve Repair" })
    if let existing = try context.fetch(desc).first {
        return existing.id
    }

    let domainFeed = Feed(
        title: "Mitral Valve Repair",
        categoryPath: ["Cardiac Surgery", "Mitral Valve"],
        query: .andGroup(
            [
                .mesh(term: "Mitral Valve", majorTopic: true),
                .keyword(term: "repair", field: .titleAbstract)
            ],
            filters: QueryFilters(date: .lastDays(365), humansOnly: true, englishOnly: true)
        ),
        sort: .pubDate,
        pageSize: 20
    )

    let rec = try FeedRecord.fromDomain(domainFeed)
    context.insert(rec)
    try context.save()
    return rec.id
}

@MainActor
func refreshMitralFeed(context: ModelContext) {
    Task {
        do {
            let repo = ArticleRepositorySwiftData()
            let feedID = try seedMitralFeedIfMissing(context: context)
            let fresh = try await repo.refresh(feedID: feedID, context: context)
            print("Stored:", fresh.count)
        } catch {
            print("Refresh failed:", error)
        }
    }
}
