import Foundation

func localizedPeopleNavigationTitle(isCrew: Bool, spaceName: String?) -> String {
    guard let spaceName, !spaceName.isEmpty else {
        return isCrew ? String(localized: "people.title.crew") : String(localized: "people.title.people")
    }

    let format = isCrew ? String(localized: "people.title.crewInSpace") : String(localized: "people.title.peopleInSpace")
    return String(format: format, spaceName)
}

func localizedPeopleMemberSectionTitle(isCrew: Bool, spaceName: String?) -> String {
    guard let spaceName, !spaceName.isEmpty else {
        return isCrew ? String(localized: "people.title.crew") : String(localized: "people.section.membersFallback")
    }

    let format = isCrew ? String(localized: "people.title.crewInSpace") : String(localized: "people.title.peopleInSpace")
    return String(format: format, spaceName)
}

func localizedPeopleEmptyMembersDescription(spaceName: String) -> String {
    String(format: String(localized: "people.empty.members.description"), spaceName)
}

func localizedRoleSelfProtectionWarning() -> String {
    String(localized: "roles.warning.selfProtection")
}

func localizedRolePermissionSummary(_ permissions: SpaceRolePermissions) -> String {
    var values: [String] = [String(localized: "roles.permission.view")]

    if permissions.canCreateItems { values.append(String(localized: "roles.permission.create")) }
    if permissions.canEditItems { values.append(String(localized: "roles.permission.edit")) }
    if permissions.canDeleteItems { values.append(String(localized: "roles.permission.delete")) }
    if permissions.canInviteMembers { values.append(String(localized: "roles.permission.invite")) }
    if permissions.canManageGroupSettings { values.append(String(localized: "roles.permission.manageGroup")) }
    if permissions.canManageRoles { values.append(String(localized: "roles.permission.manageRoles")) }

    return values.joined(separator: " • ")
}
