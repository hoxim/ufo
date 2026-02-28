
import Foundation
import SwiftData

@Model
final class LinkedThing {
    var parentId: UUID    // ID incident/mission (parent)
    var childId: UUID     // ID attached thing (child)
    var childType: String // "mission", "note", "manifest"
    
    init(parentId: UUID, childId: UUID, childType: String) {
        self.parentId = parentId
        self.childId = childId
        self.childType = childType
    }
}
