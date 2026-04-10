import Foundation
import SwiftData

@Model
final class BudgetSpaceSettings {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var openingBalance: Double
    var currencyCode: String
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var pendingSync: Bool

    init(
        id: UUID,
        spaceId: UUID,
        openingBalance: Double = 0,
        currencyCode: String = "PLN",
        updatedBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.openingBalance = openingBalance
        self.currencyCode = currencyCode
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = updatedBy
        self.pendingSync = false
    }
}
