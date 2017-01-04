//
//  VersionInfo.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 04/01/2017.
//  Copyright © 2017 Nicolas Gaulard-Querol. All rights reserved.
//

import Foundation

struct VersionInfo {
    let version: String
    let apiVersion: String
    let gitCommit: String
    let goVersion: String
    let os: String
    let arch: String
    let kernelVersion: String
    let buildTime: Date

    init(json: [String: Any]) throws {
        guard let version = json["Version"] as? String,
            let apiVersion = json["ApiVersion"] as? String,
            let gitCommit = json["GitCommit"] as? String,
            let goVersion = json["GoVersion"] as? String,
            let os = json["Os"] as? String,
            let arch = json["Arch"] as? String,
            let kernelVersion = json["KernelVersion"] as? String,
            let buildTimeString = json["BuildTime"] as? String,
            let buildTime = dateFormatter.date(from: buildTimeString) else {
            throw JSONError.invalidJSON
        }

        self.version = version
        self.apiVersion = apiVersion
        self.gitCommit = gitCommit
        self.goVersion = goVersion
        self.os = os
        self.arch = arch
        self.kernelVersion = kernelVersion
        self.buildTime = buildTime
    }
}
