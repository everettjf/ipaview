//
//  UnzipManager.swift
//  IPAView
//
//  Created by everettjf on 2023/12/24.
//
import Foundation
import ZIPFoundation

class UnzipManager : NSObject {
    var progressHandler: ((Double) -> Void)?
    private var progressObservation: NSKeyValueObservation?


    func getUnzipDirectory()-> URL {
        let dir = Utils.getCacheDirectory()
        if !Utils.directoryExists(at: dir) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func getEmptyUnzipDirectoryForFile(path: URL) -> URL {
        let name = path.lastPathComponent
        let dir = getUnzipDirectory()
        
        let target = dir.appending(path: name)
        if Utils.directoryExists(at: target) {
            try? FileManager.default.removeItem(at: target)
        }
        
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }

    func unzipFile(at sourceURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let fileManager = FileManager.default

        let tempDirectoryURL = getEmptyUnzipDirectoryForFile(path: sourceURL)
        
        print("temp dir : \(tempDirectoryURL)")

        let progress = Progress(totalUnitCount: 1)
        progressObservation = progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in
            self?.progressHandler?(progress.fractionCompleted)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try fileManager.unzipItem(at: sourceURL, to: tempDirectoryURL, progress: progress)
                DispatchQueue.main.async {
                    self.progressObservation = nil
                    completion(.success(tempDirectoryURL))
                }
            } catch {
                DispatchQueue.main.async {
                    self.progressObservation = nil
                    completion(.failure(error))
                }
            }
        }
    }
}
