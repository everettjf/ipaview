//
//  ContentView.swift
//  IPAView
//
//  Created by everettjf on 2023/12/23.
//

import SwiftUI
import SwiftData


struct ContentView: View {
    @StateObject private var sharedModel = SharedModel()
    
    var body: some View {
        NavigationSplitView {
            List(sharedModel.items, selection: $sharedModel.selectedItem) { item in
                Label(item.name, systemImage: item.directory ? "folder" : "file")
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            if let itemId = sharedModel.selectedItem,
               let item = sharedModel.items.first(where: { $0.id == itemId }) {
                DetailView(item: item)
            } else {
                DropView()
            }
        }
        .environmentObject(sharedModel)
        .onChange(of: sharedModel.selectedItem, { oldValue, newValue in
            if oldValue == nil {
                print("initial load")
            }
            if let itemId = newValue {
                sharedModel.openFile(itemID: itemId)
            }
        })
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: showFeedback) {
                    Label("Feedback", systemImage: "questionmark.circle")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: showInspector) {
                    Label("Audit Report", systemImage: "checklist")
                }
            }
        }
        .searchable(text: $sharedModel.fileSearchText, placement: .toolbar) {
            // suggestions, todo future versions
        }
        .onChange(of: sharedModel.fileSearchText) { oldValue, newValue in
            print("on search confirm :  new value \(newValue)")
        }
        .sheet(isPresented: $sharedModel.showInspector) {
            InspectorView()
                .environmentObject(sharedModel)
                .frame(minWidth: 720, idealWidth: 820, minHeight: 520, idealHeight: 620)
        }
        .frame(minWidth: 600, minHeight: 300)
        .toast(isShowing: $sharedModel.showToast, text: sharedModel.toastMessage)

    }
    
    private func showFeedback() {
        // Your feedback action here
        print("Feedback button tapped")
        Utils.openURL("https://ipaview.github.io/")
    }
    
    private func showInspector() {
        sharedModel.showInspector.toggle()
    }
}

#Preview {
    ContentView()
}
