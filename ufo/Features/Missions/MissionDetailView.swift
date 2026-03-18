import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MissionDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let mission: Mission
    let onEdit: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        if let iconName = mission.iconName, !iconName.isEmpty {
                            Image(systemName: iconName)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color(hex: mission.iconColorHex ?? "#F59E0B"))
                        }
                        Text(mission.title)
                            .font(.title2.bold())
                    }

                    HStack(spacing: 10) {
                        Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(mission.isCompleted ? .green : .gray)
                        Text(mission.isCompleted ? "Completed" : "Open")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Label(MissionPriority(rawValue: mission.resolvedPriority)?.localizedLabel ?? mission.resolvedPriority.capitalized, systemImage: "flag")
                            .font(.caption)
                        if mission.isRecurringValue {
                            Label("Recurring", systemImage: "repeat")
                                .font(.caption)
                        }
                        if let dueDate = mission.dueDate {
                            Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                .font(.caption)
                        }
                        if let savedPlaceName = mission.savedPlaceName, !savedPlaceName.isEmpty {
                            Label(savedPlaceName, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)

                    if !mission.missionDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("missions.editor.field.description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(mission.missionDescription)
                                .font(.body)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("missions.editor.field.difficulty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            ForEach(0..<mission.difficulty, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }

                    missionImageView

                    Text(mission.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Mission")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onEdit()
                    } label: {
                        Label("common.edit", systemImage: "pencil")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var missionImageView: some View {
        if let imageData = mission.imageData {
            #if os(iOS)
            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            #elseif os(macOS)
            if let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            #endif
        }
    }
}

#Preview("Mission Detail") {
    let mission = Mission(
        spaceId: UUID(),
        title: "Prepare emergency bag",
        missionDescription: "Check batteries, flashlight and first aid kit.",
        difficulty: 3
    )
    mission.iconName = "backpack"
    mission.iconColorHex = "#F59E0B"

    return MissionDetailView(
        mission: mission,
        onEdit: {}
    )
}
