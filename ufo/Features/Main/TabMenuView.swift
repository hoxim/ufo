//
//  TabMenuView.swift
//  ufo
//
//  Created by Marcin Ryzko on 10/02/2026.
//

import SwiftUI

struct TabMenuView: View {
    @Binding var selectedTab: TabItem
    var profileMenu: AnyView

    var body: some View {
        #if os(iOS)
        ZStack(alignment: .bottom) {
            currentTabView
                .padding(.top, 10)

            VStack {
                HStack {
                    profileMenu
                    Spacer()
                    HStack(spacing: 12) {
                        floatingAction(symbol: "bell")
                        floatingAction(symbol: "plus")
                    }
                }
                .padding(.horizontal, 16)
                Spacer()
            }

            HStack(spacing: 4) {
                floatingTabButton(tab: .missions, systemImage: "target", title: "Missions")
                floatingTabButton(tab: .incidents, systemImage: "bolt.horizontal", title: "Incidents")
                floatingTabButton(tab: .lists, systemImage: "checklist", title: "Lists")
                floatingTabButton(tab: .messages, systemImage: "message", title: "Chat")
                floatingTabButton(tab: .spaces, systemImage: "person.3", title: "Spaces")
            }
            .padding(8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        #else
        TabView(selection: $selectedTab) {
            MissionsListView()
                .tabItem { Label("Missions", systemImage: "target") }
                .tag(TabItem.missions)
            IncidentsListView()
                .tabItem { Label("Incidents", systemImage: "bolt.horizontal") }
                .tag(TabItem.incidents)
            LinksListView()
                .tabItem { Label("Links", systemImage: "link") }
                .tag(TabItem.links)
            SharedListsView()
                .tabItem { Label("Lists", systemImage: "checklist") }
                .tag(TabItem.lists)
            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.bar") }
                .tag(TabItem.budget)
            LocationsView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(TabItem.locations)
            MessagesView()
                .tabItem { Label("Chat", systemImage: "message") }
                .tag(TabItem.messages)
            SpaceListView()
                .tabItem { Label("Spaces", systemImage: "person.3") }
                .tag(TabItem.spaces)
        }
        .overlay(alignment: .topTrailing) {
            profileMenu.padding()
        }
        #endif
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .missions:
            MissionsListView()
        case .incidents:
            IncidentsListView()
        case .links:
            LinksListView()
        case .lists:
            SharedListsView()
        case .budget:
            BudgetView()
        case .locations:
            LocationsView()
        case .messages:
            MessagesView()
        case .spaces, .profile:
            SpaceListView()
        }
    }

    private func floatingAction(symbol: String) -> some View {
        Button {} label: {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func floatingTabButton(tab: TabItem, systemImage: String, title: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.subheadline.bold())
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                selectedTab == tab
                ? Color.white.opacity(0.18)
                : Color.clear,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}
