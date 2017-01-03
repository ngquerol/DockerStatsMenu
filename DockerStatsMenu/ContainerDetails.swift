//
//  ContainerDetails.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 17/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Foundation

fileprivate let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()

    formatter.locale = Locale(identifier: "en")
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'.'SSSSSSSSSZ"

    return formatter
}()

struct ContainerDetails {
    let id: String
    let name: String
    let image: String
    let created: Date
    let command: String
    let state: ContainerState

    init(json: [String: Any]) throws {
        guard let id = json["Id"] as? String,
            let name = json["Name"] as? String,
            let config = json["Config"] as? [String: Any],
            let image = config["Image"] as? String,
            let created = json["Created"] as? String,
            let createdDate = dateFormatter.date(from: created),
            let command = config["Cmd"] as? [String],
            let state = json["State"] as? [String: Any],
            let status = state["Status"] as? String else {
            throw JSONError.invalidJSON
        }

        self.id = id
        self.name = name
        self.image = image
        self.created = createdDate
        self.command = command.joined(separator: " ")
        self.state = ContainerState(rawValue: status)
    }
}

extension ContainerDetails: Equatable {
    
    static func == (lhs: ContainerDetails, rhs: ContainerDetails) -> Bool {
        return lhs.id == rhs.id
    }
}

extension ContainerDetails: Comparable {

    static func < (lhs: ContainerDetails, rhs: ContainerDetails) -> Bool {
        return lhs.created < rhs.created
    }
}
