#if os(watchOS)
import SwiftUI

struct WatchBudgetFeatureView: View {
    @Environment(WatchAppModel.self) private var model

    @State private var snapshot: WatchBudgetSnapshot?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading budget")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if let snapshot {
                Section("Balance") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.currentBalance.formatted(.currency(code: snapshot.currencyCode)))
                            .font(.headline)
                        Text("Current ledger balance")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Spending") {
                    LabeledContent("Today") {
                        Text(snapshot.spentToday.formatted(.currency(code: snapshot.currencyCode)))
                            .foregroundStyle(.red)
                    }

                    LabeledContent("This week") {
                        Text(snapshot.spentThisWeek.formatted(.currency(code: snapshot.currencyCode)))
                            .foregroundStyle(.red)
                    }
                }

                Section("Recurring") {
                    if let nextRecurring = snapshot.nextRecurring {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(nextRecurring.title)
                                .font(.headline)
                            Text(nextRecurring.amount.formatted(.currency(code: snapshot.currencyCode)))
                                .foregroundStyle(nextRecurring.kind == "expense" ? .red : .green)
                            Text(nextRecurring.nextDate, style: .date)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No recurring items yet")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Budget")
        .task(id: model.selectedSpaceID) {
            await loadBudget()
        }
        .refreshable {
            await loadBudget()
        }
    }

    private func loadBudget() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snapshot = try await model.fetchBudgetSnapshot()
            errorMessage = nil
        } catch {
            snapshot = nil
            errorMessage = "Unable to load budget right now."
        }
    }
}

#endif
