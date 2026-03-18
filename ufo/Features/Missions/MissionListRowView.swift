import SwiftUI

struct MissionListRowView: View {
    let mission: Mission
    let onToggleCompleted: () -> Void
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                if let iconName = mission.iconName, !iconName.isEmpty {
                    Image(systemName: iconName)
                        .foregroundStyle(Color(hex: mission.iconColorHex ?? "#F59E0B"))
                }

                Button(action: onToggleCompleted) {
                    Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(mission.isCompleted ? .green : .gray)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mission.title)
                        .font(.headline)
                        .lineLimit(1)

                    if !mission.missionDescription.isEmpty {
                        Text(mission.missionDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        Text(MissionPriority(rawValue: mission.resolvedPriority)?.localizedLabel ?? mission.resolvedPriority.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if mission.isRecurringValue {
                            Text("Recurring")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let dueDate = mission.dueDate {
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if mission.imageData != nil {
                        Text("common.imageAttached")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 2) {
                    ForEach(0..<mission.difficulty, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Menu {
                Button(action: onOpen) {
                    Label("Podglad", systemImage: "eye")
                }
                Button(action: onEdit) {
                    Label("common.edit", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("common.delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }
}
