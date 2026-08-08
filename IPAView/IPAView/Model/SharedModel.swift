//
//  SharedModel.swift
//  IPAView
//
//  Created by everettjf on 2023/12/29.
//

import Foundation
import SwiftUI
import IPAAuditCore

class SharedModel: ObservableObject {
    // toast
    @Published var showToast = false
    @Published var toastMessage = ""
    
    // extracting
    @Published var unzipExecuting: Bool = false
    @Published var unzipProgress: Double = 0
    @Published var unzipStatus: String = ""
    
    // sidebar items
    @Published var items: [SidebarItemInfo] = []
    @Published var selectedItem: SidebarItemInfo.ID?
    
    // files
    @Published var files: [FileItemInfo] = []
    @Published var selectedFiles = Set<FileItemInfo.ID>()
    @Published var fileSearchText = ""
    @Published var currentPath: URL = URL(filePath: "")
    
    var fileSearchResults: [FileItemInfo] {
        if fileSearchText.isEmpty {
            return files
        }
        
        return files.filter { file in
            return file.name.lowercased().contains(fileSearchText.lowercased())
        }
    }
    
    // inspector
    @Published var showInspector = false
    @Published var inspectItems: [InspectItemInfo] = []
    @Published var selectedInspectItems = Set<InspectItemInfo.ID>()
    @Published var auditReport: IPAAuditReport?
    @Published var auditError: String?
    
    // recent files
    @Published var recentFiles: [String] = []
    @Published var filesInDownloads: [URL] = []
    
    // for the initial root url
    var rootUrl: URL = URL(filePath: "")
    
    // list stuff
    func loadInitialPath(dir: URL) {
        DispatchQueue.main.async {
            print("load path : \(dir)")
            self.listInitialFiles(path: dir)
        }
    }
    
    private func listInitialFiles(path: URL) {
        // items
        self.rootUrl = path
        items = ExploreManager.listKeyItems(path: rootUrl)
        // select the app
        let appItemId = items.first { $0.name.hasSuffix(".app")}?.id
        if let appItemId = appItemId {
            selectedItem = appItemId
        } else {
            if let firstItemId = items.first?.id {
                selectedItem = firstItemId
            }
        }
        
        // inspector
        showInspector = true
        DispatchQueue.global(qos: .userInitiated).async {
            let results = InspectorManager.analyzeDirectory(at: self.rootUrl)
            let auditResult = Result { try IPAAuditor().audit(extractedArchive: path) }
            DispatchQueue.main.async {
                self.inspectItems = results
                switch auditResult {
                case .success(let report):
                    self.auditReport = report
                    self.auditError = nil
                case .failure(let error):
                    self.auditReport = nil
                    self.auditError = error.localizedDescription
                }
            }
        }
    }
    
    private func loadFilesFromPath(path: URL) {
        self.currentPath = path
        self.files = ExploreManager.listFiles(path: path)
        self.selectedFiles = []
    }
    
    func openDirectory(path: URL) {
        print("open path : \(path)")
        loadFilesFromPath(path: path)
    }
    
    func openFile(itemID: SidebarItemInfo.ID) {
        let item = self.items.first { $0.id == itemID }
        guard let item = item else {
            return
        }
        
        if item.directory {
            loadFilesFromPath(path: item.path)
        } else {
            print("can not open file now")
        }
    }
    
    func revealInFinder(fileID: FileItemInfo.ID) {
        let file = self.files.first {$0.id == fileID}
        guard let file = file else {
            return
        }
        
        print("open file : \(file.name)")
        
        Utils.revealInFinder(fileURL: file.path)
    }
    
    func searchFileName(fileID: FileItemInfo.ID, engine: String) {
        let file = self.files.first {$0.id == fileID}
        guard let file = file else {
            return
        }
        
        print("search file : \(file.name)")
        Utils.searchWithDefaultBrowser(query: file.name, searchEngine: engine)
    }
    
    
    func copyFileItemInfoToPasteboard(fileID: FileItemInfo.ID, field: String) {
        let file = self.files.first {$0.id == fileID}
        guard let file = file else {
            return
        }
        copyFileItemInfoToPasteboard(path: file.path, field: field)
    }
    
    func copyFileItemInfoToPasteboard(path: URL, field: String) {
        switch field {
        case "relative-path":
            let root = rootUrl.path(percentEncoded: false)
            let relativePath = path.path(percentEncoded: false).replacingOccurrences(of: root, with: "")
            print("relative path = \(relativePath)")
            Utils.copyToPasteboard(string: relativePath)
            showToastMessage("Relative path copied : \(relativePath)")
        case "full-path":
            let path = path.path(percentEncoded: false)
            Utils.copyToPasteboard(string: path)
            showToastMessage("Full path copied : \(path)")
        case "file-name":
            let name = path.lastPathComponent
            Utils.copyToPasteboard(string: name)
            showToastMessage("File name copied : \(name)")
        default:
            print("unknown field : \(field)")
        }
    }
    
    
    func openFile(fileID: FileItemInfo.ID) {
        let file = self.files.first {$0.id == fileID}
        guard let file = file else {
            return
        }
        
        print("open file : \(file.name)")
        
        if file.directory {
            loadFilesFromPath(path: file.path)
        } else {
            Utils.openFile(file.path)
        }
    }
    
    // unzip stuff
    private var unzipManager = UnzipManager()
    
    func unzipFile(at sourceURL: URL) {
        if self.unzipExecuting {
            print("unzip executing, ignore")
            return
        }
        
        unzipManager.progressHandler = { [weak self] progress in
            DispatchQueue.main.async {
                self?.unzipProgress = progress
                self?.unzipStatus = "Progress \(Int(progress * 100))%"
            }
        }
        
        self.unzipExecuting = true
        unzipManager.unzipFile(at: sourceURL) { [weak self] result in
            DispatchQueue.main.async {
                self?.unzipExecuting = false
                switch result {
                case .success(let directoryURL):
                    self?.unzipStatus = "Extracted to: \(directoryURL.path(percentEncoded: false))"
                    self?.listInitialFiles(path: directoryURL)
                case .failure(let error):
                    self?.unzipStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    
    func showToastMessage(_ message: String) {
        self.toastMessage = message
        withAnimation {
            showToast = true
        }
        
        // Hide toast after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.showToast = false
                self.toastMessage = ""
            }
        }
        
    }
    
    func loadRecentFiles() {
        DispatchQueue.global().async {
            let files = recentFileManager.getRecentFiles()
            DispatchQueue.main.async {
                self.recentFiles = files
            }
        }
    }
    
    func removeRecentFile(filePath: String) {
        recentFileManager.removeFile(filePath: filePath)
        loadRecentFiles()
    }
    
    func loadUserDownloadsFiles() {
        DispatchQueue.global().async {
            let result = Utils.listFilesInUserDownloadsDirectory(fileExtension: "ipa")
            DispatchQueue.main.async {
                switch result {
                case .success(let files):
                    self.filesInDownloads = files
                case .failure(let error):
                    if case .error(let message) = error {
                        self.showToastMessage(message)
                    }
                }
            }
        }
    }
}
