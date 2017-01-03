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

extension JSONError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidJSON: return "Could not decode JSON response"
        }
    }
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
        case .running: return "Running"
        case .paused: return "Paused"
        case .exited: return "Exited"
        case .unknown: return "Unknown"
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
    let command: String
    let status: String
    let state: ContainerState

    init(json: [String: Any]) throws {
        guard let id = json["Id"] as? String,
            let names = json["Names"] as? [String],
            let image = json["Image"] as? String,
            let created = json["Created"] as? TimeInterval,
            let command = json["Command"] as? String,
            let status = json["Status"] as? String,
            let state = json["State"] as? String else {
            throw JSONError.invalidJSON
        }

        self.id = id
        self.names = names
        self.image = image
        self.created = Date(timeIntervalSince1970: created)
        self.command = command
        self.status = status
        self.state = ContainerState(rawValue: state)
    }
}

extension Container: Equatable {

    static func == (lhs: Container, rhs: Container) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Container: Comparable {

    static func < (lhs: Container, rhs: Container) -> Bool {
        return lhs.created < rhs.created
    }
}
