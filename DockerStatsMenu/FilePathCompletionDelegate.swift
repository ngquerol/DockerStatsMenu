//
//  FilePathCompletionDelegate.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 30/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class FilePathCompletionDelegate: NSObject { }

extension FilePathCompletionDelegate: CompletableTextFieldDelegate {

    func getCompletions(for text: String) -> [String] {

        var completions = [String]()

        _ = text.completePath(into: nil, caseSensitive: true, matchesInto: &completions, filterTypes: nil)

        return completions.map { path in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            return isDir.boolValue ? path + "/" : path
        }
    }
}
