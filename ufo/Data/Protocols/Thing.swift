import Foundation

protocol Thing: AnyObject {
    var id: UUID { get }
    var spaceId: UUID { get }
    var title: String { get }
    var createdAt: Date { get }
}
