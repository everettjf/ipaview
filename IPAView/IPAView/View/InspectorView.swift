//
//  InspectorView.swift
//  IPAView
//
//  Created by everettjf on 2023/12/31.
//

import SwiftUI
struct InspectorView: View {
    @EnvironmentObject var sharedModel: SharedModel

    var body: some View {
        Group {
            if let report = sharedModel.auditReport {
                AuditReportView(report: report)
            } else if let error = sharedModel.auditError {
                ContentUnavailableView("Audit unavailable", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView("Auditing app…")
            }
        }
    }
}

#Preview {
    InspectorView()
        .environmentObject(SharedModel())
}
