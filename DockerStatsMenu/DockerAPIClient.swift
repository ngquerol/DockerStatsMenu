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
    case unpauseContainer(id: String)
    case startContainer(id: String)
    case stopContainer(id: String)
    case containers
    case allContainers
}

extension DockerAPIRoute: APIEndpoint {
    var baseURL: URL {
        return URL(string: "localhost:2376")!
    }

    var path: URL {
        switch self {
        case .pauseContainer(let id): return URL(string: "/containers")!.appendingPathComponent(id).appendingPathComponent("pause")
        case .unpauseContainer(let id): return URL(string: "/containers")!.appendingPathComponent(id).appendingPathComponent("unpause")
        case .startContainer(let id): return URL(string: "/containers")!.appendingPathComponent(id).appendingPathComponent("start")
        case .stopContainer(let id): return URL(string: "/containers")!.appendingPathComponent(id).appendingPathComponent("stop")

        case .containers: return URL(string: "/containers/json")!
        case .allContainers:
            var components = URLComponents(string: "/containers/json")!
            components.queryItems = [URLQueryItem(name: "all", value: "1")]
            return components.url!
        }
    }
}

// MARK: API client

typealias ResponseHandler = (Response?, Error?) -> Void

enum APIError: Error, CustomStringConvertible {
    case invalidResponse

    var description: String {
        switch self {
        case .invalidResponse:
            return "Got invalid response"
        }
    }

    var localizedDescription: String {
        return description
    }
}

protocol DockerAPI {
    func connect() throws
    func pauseContainer(withId id: String, completion: @escaping (Error?) -> Void)
    func unpauseContainer(withId id: String, completion: @escaping (Error?) -> Void)
    func stopContainer(withId id: String, completion: @escaping (Error?) -> Void)
    func startContainer(withId id: String, completion: @escaping (Error?) -> Void)
    func getContainersList(showAll: Bool, completion: @escaping ([Container]?, Error?) -> Void)
}

class SocketDockerAPI {
    fileprivate var clientSocket: UnixClientSocket

    init(socketPath path: String) {
        clientSocket = UnixClientSocket(path: path)
    }

    deinit {
        clientSocket.close()
    }

    fileprivate func sendRequest(to route: DockerAPIRoute, via method: String, with data: Data, completion: @escaping (Error?) -> Void) {
        let request = Request(
            httpVersion: kCFHTTPVersion1_1 as String,
            headers: [
                "Host": route.baseURL.absoluteString,
                "Accept": "application/json",
                "User-Agent": "DockerStatsMenu"
            ],
            body: data,
            url: route.path,
            method: method
        )

        do {
            let serializedRequest = try request.serialized()
            clientSocket.write(data: serializedRequest as Data) { error in completion(error) }
        } catch (let error) {
            return completion(error)
        }


    }

    fileprivate func readResponse(from data: Data) throws -> Response {
        let response = try Response(data: data)

        if !(200..<300 ~= response.statusCode) {
            throw APIError.invalidResponse
        }

        return response
    }

    fileprivate func doRequest(to route: DockerAPIRoute, via method: String, with data: Data = Data(), completion: @escaping (Response?, Error?) -> Void) {
        var responseData = Data()

        clientSocket.readEventHandler = { data, error in
            guard let data = data, error == nil else {
                return completion(nil, error)
            }

            responseData.append(data)

            do {
                let response = try self.readResponse(from: responseData)
                completion(response, nil)
                responseData.removeAll()
                self.clientSocket.readEventHandler = nil
            } catch HTTPMessageWrapperError.incompleteMessage {
                return // wait for additional data
            } catch (let error) {
                completion(nil, error)
                responseData.removeAll()
                self.clientSocket.readEventHandler = nil
            }
        }

        sendRequest(to: route, via: method, with: data) { error in
            guard error == nil else {
                return completion(nil, error)
            }
        }
    }
}

extension SocketDockerAPI: DockerAPI {
    func connect() throws {
        try clientSocket.connect()
    }

    func pauseContainer(withId id: String, completion: @escaping (Error?) -> Void) {
        doRequest(to: .pauseContainer(id: id), via: "POST") { _, error in
            completion(error)
        }
    }

    func unpauseContainer(withId id: String, completion: @escaping (Error?) -> Void) {
        doRequest(to: .unpauseContainer(id: id), via: "POST") { _, error in
            completion(error)
        }
    }

    func stopContainer(withId id: String, completion: @escaping (Error?) -> Void) {
        doRequest(to: .stopContainer(id: id), via: "POST") { _, error in
            completion(error)
        }
    }

    func startContainer(withId id: String, completion: @escaping (Error?) -> Void) {
        doRequest(to: .startContainer(id: id), via: "POST") { _, error in
            completion(error)
        }
    }

    func getContainersList(showAll: Bool, completion: @escaping ([Container]?, Error?) -> Void) {
        doRequest(to: showAll ? .allContainers : .containers, via: "GET") { response, error in
            guard error == nil, let responseBody = response?.body else {
                return completion(nil, error)
            }

            do {
                let containersJSONArray = try JSONSerialization.jsonObject(with: responseBody, options: []) as! [[String: Any]]
                let containers = try containersJSONArray.map { try Container(json: $0) }
                completion(containers, nil)
            } catch (let error) {
                completion(nil, error)
            }
        }
    }
}
