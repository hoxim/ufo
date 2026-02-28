//
//  IncidentsListView.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import SwiftUI
import SwiftData

struct IncidentsListView: View {
    @Query(sort: \Incident.occurrenceDate, order: .reverse) private var incidents: [Incident]
    
    var body: some View {
        NavigationStack {
            List(incidents) { incident in
                VStack(alignment: .leading) {
                    Text(incident.title).font(.headline)
                    Text(incident.occurrenceDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                }
            }
            .navigationTitle("Incidents Log")
        }
    }
}
