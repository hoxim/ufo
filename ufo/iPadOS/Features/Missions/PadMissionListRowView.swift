#if os(iOS)

import SwiftUI

struct PadMissionListRowView: View {
    let mission: Mission
    let onToggleCompleted: () -> Void
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 12) {
                leadingIconSlot
                completionButton
                contentColumn
                Spacer(minLength: 8)
                difficultyStars
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

    private var leadingIconSlot: some View {
        Group {
            if let iconName = mission.iconName, !iconName.isEmpty {
                Image(systemName: iconName)
                    .foregroundStyle(Color(hex: mission.iconColorHex ?? "#F59E0B"))
            } else {
                Color.clear
            }
        }
        .frame(width: 18, alignment: .center)
    }

    private var completionButton: some View {
        Button(action: onToggleCompleted) {
            Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(mission.isCompleted ? .green : .gray)
        }
        .buttonStyle(.plain)
        .frame(width: 22, alignment: .center)
    }

    private var contentColumn: some View {
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
                Text(mission.priority.localizedLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if mission.isRecurring {
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
    }

    private var difficultyStars: some View {
        HStack(spacing: 2) {
            ForEach(0..<mission.difficulty, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
    }
}

private func makePadMissionRowPreviewMission() -> Mission {
    let mission = Mission(
        spaceId: UUID(),
        title: "Prepare emergency bag",
        missionDescription: "Pack documents, flashlight and basic medicine.",
        difficulty: 3,
        dueDate: .now.addingTimeInterval(86_400),
        priority: MissionPriority.high.rawValue,
        isRecurring: true,
        createdBy: UUID()
    )
    mission.iconName = "flag.fill"
    mission.iconColorHex = "#F59E0B"
    return mission
}

#Preview("Pad Mission Row") {
    PadMissionListRowView(
        mission: makePadMissionRowPreviewMission(),
        onToggleCompleted: {},
        onOpen: {},
        onEdit: {},
        onDelete: {}
    )
    .padding()
}

#endif
