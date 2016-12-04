//
//  Container.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 25/11/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Foundation

enum JSONError: Error {
    case invalidJSON
}

enum ContainerState {
    case running
    case paused
    case exited
    case unknown
}

extension ContainerState: RawRepresentable {
    var rawValue: String {
        switch self {
        case .running: return "running"
        case .paused: return "paused"
        case .exited: return "exited"
        case .unknown: return "unknown"
        }
    }

    init(rawValue: String) {
        switch rawValue {
        case "running": self = .running
        case "paused": self = .paused
        case "exited": self = .exited
        default : self = .unknown
        }
    }
}

struct Container {
    let id: String
    let names: [String]
    let image: String
    let created: Date
    let status: String
    let state: ContainerState

    init(json: [String: Any]) throws {
        guard let id = json["Id"] as? String,
            let names = json["Names"] as? [String],
            let image = json["Image"] as? String,
            let created = json["Created"] as? UInt64,
            let status = json["Status"] as? String,
            let state = json["State"] as? String else {
            throw JSONError.invalidJSON
        }

        self.id = id
        self.names = names
        self.image = image
        self.created = Date(timeIntervalSince1970: TimeInterval(created))
        self.status = status
        self.state = ContainerState(rawValue: state)
    }
}
