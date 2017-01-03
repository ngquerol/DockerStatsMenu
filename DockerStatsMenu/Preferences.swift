//
//  Preferences.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 18/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Foundation

struct Preferences {
    static var shared: Preferences = {
        return Preferences()
    }()

    static let DockerSocketPathChangedNotification = Notification.Name("DockerSocketPathChangedNotification")
    static let ContainersUpdateIntervalChangedNotification = Notification.Name("ContainersUpdateIntervalChangedNotification")
    static let ShowAllContainersChangedNotification = Notification.Name("ShowAllContainersChangedNotification")

    private struct Keys {
        static let showAllContainers = "showAllContainers"
        static let containersUpdateInterval = "containersUpdateInterval"
        static let dockerSocketPath = "dockerSocketPath"
    }

    private struct DefaultValues {
        static let showAllContainers: Bool = true
        static let containersUpdateInterval: Int = 1
        static let dockerSocketPath: String = "/var/run/docker.sock"
    }

    private init() { }

    var showAllContainers: Bool {
        get {
            guard let showAll = UserDefaults.standard.object(forKey: Keys.showAllContainers) as? Bool else {
                return DefaultValues.showAllContainers
            }

            return showAll
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showAllContainers)
            NotificationCenter.default.post(name: Preferences.ShowAllContainersChangedNotification, object: nil)
        }
    }

    var containersUpdateInterval: Int {
        get {
            guard let updateInterval = UserDefaults.standard.object(forKey: Keys.containersUpdateInterval) as? Int else {
                return DefaultValues.containersUpdateInterval
            }

            return updateInterval
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Keys.containersUpdateInterval)
            NotificationCenter.default.post(name: Preferences.ContainersUpdateIntervalChangedNotification, object: nil)
        }
    }

    var dockerSocketPath: String {
        get {
            guard let socketPath = UserDefaults.standard.object(forKey: Keys.dockerSocketPath) as? String else {
                return DefaultValues.dockerSocketPath
            }

            return socketPath
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Keys.dockerSocketPath)
            NotificationCenter.default.post(name: Preferences.DockerSocketPathChangedNotification, object: nil)
        }
    }
}
