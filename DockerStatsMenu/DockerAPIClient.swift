//
//  DockerAPI.swift
//  DockerStats
//
//  Created by Nicolas Gaulard-Querol on 13/11/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

// MARK: API routes

protocol APIEndpoint {
    var baseURL: URL { get }
    var path: URL { get }
}

enum DockerAPIRoute {
    case pauseContainer(id: String)
    case resumeContainer(id: String)
    case startContainer(id: String)
    case stopContainer(id: String)
    case removeContainer(id: String)
    case container(id: String)
    case containers
    case allContainers
}

extension DockerAPIRoute: APIEndpoint {
    var baseURL: URL {
        return URL(string: "localhost:2376")!
    }

    var path: URL {
        switch self {
        case .pauseContainer(let id):
            return URL(string: "/containers")!.appendingPathComponent(id).appendingPathComponent("pause")
        case .resumeContainer(let id):
            return URL(string: "/containers")!.appendingPathComponent(id).appendingPathComponent("unpause")
        case .startContainer(let id):
            return URL(string: "/containers")!.appendingPathComponent(id).appendingPathComponent("start")
        case .stopContainer(let id):
            return URL(string: "/containers")!.appendingPathComponent(id).appendingPathComponent("stop")
        case .removeContainer(let id):
            return URL(string: "/containers")!.appendingPathComponent(id)
        case .container(let id):
            return URL(string: "/containers")!.appendingPathComponent(id).appendingPathComponent("json")
        case .containers:
            return URL(string: "/containers")!.appendingPathComponent("json")
        case .allContainers:
            var components = URLComponents(string: "/containers/json")!
            components.queryItems = [URLQueryItem(name: "all", value: "1")]
            return components.url!
        }
    }
}

// MARK: API client

typealias ResponseHandler = (Response?, Error?) -> Void

enum APIError: Error {
    case invalidResponse(statusCode: Int)
    case emptyResponse
}

extension APIError: LocalizedError {
    var localizedDescription: String? {
        switch self {
        case .invalidResponse(let statusCode):
            return "Got invalid response \(statusCode)"
        case .emptyResponse:
            return "Got empty response"
        }
    }
}

protocol DockerAPI {
    func connect() throws
    func pauseContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void)
    func resumeContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void)
    func stopContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void)
    func startContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void)
    func removeContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void)
    func getContainer(withId id: String, completion: @escaping (ContainerDetails?, Error?) -> Void)
    func getContainersList(showAll: Bool, completion: @escaping ([Container]?, Error?) -> Void)
}

struct SocketDockerAPI {
    fileprivate static let userAgentString = "DockerStatsMenu/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?")"
    fileprivate var clientSocket: UnixClientSocket

    init(socketPath path: String) {
        clientSocket = UnixClientSocket(path: path)
    }

    fileprivate func sendRequest(to route: DockerAPIRoute, via method: String, with data: Data = Data(), completion: @escaping (Response?, Error?) -> Void) {
        let request = Request(
            httpVersion: kCFHTTPVersion1_1 as String,
            headers: [
                "Host": route.baseURL.absoluteString,
                "Accept": "application/json",
                "User-Agent": SocketDockerAPI.userAgentString,
            ],
            body: data,
            url: route.path,
            method: method
        )

        let requestData: Data

        do {
            requestData = try request.serialized()
        } catch {
            return completion(nil, error)
        }

        clientSocket.send(data: requestData) { error in
            guard error == nil else {
                return completion(nil, error)
            }

            self.readResponse(completion: completion)
        }
    }

    fileprivate func readResponse(completion: @escaping (Response?, Error?) -> Void) {
        var responseData = Data()

        self.clientSocket.readEventHandler = { data, error in
            guard error == nil, let data = data else {
                self.clientSocket.readEventHandler = nil
                return completion(nil, error == nil ? APIError.emptyResponse : error)
            }

            responseData.append(data)

            do {
                let response = try Response(data: responseData)
                completion(response, nil)
                self.clientSocket.readEventHandler = nil
                return
            } catch HTTPMessageWrapperError.incompleteMessage {
                // wait for additional data
            } catch {
                completion(nil, error)
                self.clientSocket.readEventHandler = nil
                return
            }
        }
    }
}

extension SocketDockerAPI: DockerAPI {
    
    func connect() throws {
        try clientSocket.connect()
    }

    func pauseContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void) {
        sendRequest(to: .pauseContainer(id: id), via: "POST") { response, error in
            completion(response, error)
        }
    }

    func resumeContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void) {
        sendRequest(to: .resumeContainer(id: id), via: "POST") { response, error in
            completion(response, error)
        }
    }

    func stopContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void) {
        sendRequest(to: .stopContainer(id: id), via: "POST") { response, error in
            completion(response, error)
        }
    }

    func startContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void) {
        sendRequest(to: .startContainer(id: id), via: "POST") { response, error in
            completion(response, error)
        }
    }

    func removeContainer(withId id: String, completion: @escaping (Response?, Error?) -> Void) {
        sendRequest(to: .removeContainer(id: id), via: "DELETE") { response, error in
            completion(response, error)
        }
    }

    func getContainer(withId id: String, completion: @escaping (ContainerDetails?, Error?) -> Void) {
        sendRequest(to: .container(id: id), via: "GET") { response, error in
            guard error == nil, let responseBody = response?.body else {
                return completion(nil, error)
            }

            do {
                let containerJSON = try JSONSerialization.jsonObject(with: responseBody, options: []) as! [String: Any]
                let container = try ContainerDetails(json: containerJSON)
                completion(container, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    func getContainersList(showAll: Bool, completion: @escaping ([Container]?, Error?) -> Void) {
        sendRequest(to: showAll ? .allContainers : .containers, via: "GET") { response, error in
            guard error == nil, let responseBody = response?.body else {
                return completion(nil, error)
            }

            do {
                let containersJSONArray = try JSONSerialization.jsonObject(with: responseBody, options: []) as! [[String: Any]]
                let containers = try containersJSONArray.map { try Container(json: $0) }
                completion(containers, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}
