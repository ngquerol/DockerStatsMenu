//
//  HTTPMessageWrapper.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 23/11/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Foundation

// MARK: - HTTP request/response CoreFoundation wrappers

enum HTTPMessageWrapperError: Error {
    case incompleteMessage(reason: String)
    case encodingError(reason: String)
    case decodingError(reason: String)
}

extension HTTPMessageWrapperError: LocalizedError {
    var localizedDescription: String? {
        switch self {
        case .incompleteMessage(let reason):
            return "Incomplete HTTP message: \(reason)"
        case .encodingError(let reason):
            return "Could not encode HTTP message: \(reason)"
        case .decodingError(let reason):
            return "Could not decode HTTP message: \(reason)"
        }
    }
}

protocol HTTPMessageWrapper {
    var httpVersion: String { get set }
    var headers: [String: String] { get set }
    var body: Data { get set }

    init()

    static func createEmptyMessage() -> CFHTTPMessage

    static func getCFHTTPMessage(data: Data) throws -> CFHTTPMessage

    func serialized() throws -> Data
}

extension HTTPMessageWrapper {

    init(rawMessage message: CFHTTPMessage) throws {
        self.init()

        guard CFHTTPMessageIsHeaderComplete(message),
            let headerDictionary = CFHTTPMessageCopyAllHeaderFields(message)?.takeRetainedValue() as? [String: String],
            !headerDictionary.isEmpty else {
            throw HTTPMessageWrapperError.incompleteMessage(reason: "Incomplete or invalid header")
        }

        self.headers = headerDictionary

        guard var messageBody = CFHTTPMessageCopyBody(message)?.takeRetainedValue() as? Data else {
            throw HTTPMessageWrapperError.decodingError(reason: "Missing message body")
        }

        if let contentLength = headers["Content-Length"] {
            guard Int(contentLength) == messageBody.count else {
                throw HTTPMessageWrapperError.incompleteMessage(reason: "Message body length does not match Content-Length header")
            }
        }

        self.body = messageBody

        self.httpVersion = CFHTTPMessageCopyVersion(message).takeRetainedValue() as String
    }

    static func getCFHTTPMessage(data: Data) throws -> CFHTTPMessage {
        let message = Self.createEmptyMessage()

        let copySucceeded = data.withUnsafeBytes {
            CFHTTPMessageAppendBytes(message, $0, data.count as CFIndex)
        }

        guard copySucceeded else {
            throw HTTPMessageWrapperError.decodingError(reason: "Could not deserialize message data")
        }

        return message
    }
}

protocol HTTPRequestWrapper: HTTPMessageWrapper {
    var url: URL { get set }
    var method: String { get set }
}

extension HTTPRequestWrapper {

    init(data: Data) throws {
        let request = try Self.getCFHTTPMessage(data: data)

        try self.init(rawMessage: request)

        guard let url = CFHTTPMessageCopyRequestURL(request)?.takeRetainedValue() as? URL,
            let method = CFHTTPMessageCopyRequestMethod(request)?.takeRetainedValue() as? String else {
            throw HTTPMessageWrapperError.decodingError(reason: "Missing/malformed request URL or HTTP method")
        }

        self.url = url
        self.method = method
    }

    static func createEmptyMessage() -> CFHTTPMessage {
        return CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true).takeRetainedValue()
    }
}

protocol HTTPResponseWrapper: HTTPMessageWrapper {
    var statusCode: Int { get set }
    var statusLine: String { get set }
}

extension HTTPResponseWrapper {
    
    init(data: Data) throws {
        let response = try Self.getCFHTTPMessage(data: data)

        try self.init(rawMessage: response)

        guard let statusLine = CFHTTPMessageCopyResponseStatusLine(response)?.takeRetainedValue() as? String else {
            throw HTTPMessageWrapperError.decodingError(reason: "Missing response status line")
        }

        self.statusCode = CFHTTPMessageGetResponseStatusCode(response) as Int
        self.statusLine = statusLine

        if headers["Transfer-Encoding"] == "chunked" {
            self.body = try decodeChunkedData()
        }
    }

    private func decodeChunkLength(data: Data) throws -> Int {
        guard let chunkLengthString = String(data: data, encoding: .ascii),
            let chunkLength = Int(chunkLengthString, radix: 16) else {
            throw HTTPMessageWrapperError.decodingError(reason: "Could not decode chunk length")
        }

        return chunkLength
    }

    private mutating func decodeChunkedData() throws -> Data {
        guard !body.isEmpty else {
            throw HTTPMessageWrapperError.incompleteMessage(reason: "Empty chunked message body")
        }

        // As per RFC 2145, the last chunk's length should be equal to zero, with no chunk data
        // that follows it.
        let messageTerminator: [UInt8] = [0x30, 0x0D, 0x0A, 0x0D, 0x0A]

        guard body.suffix(5).elementsEqual(messageTerminator) else {
            throw HTTPMessageWrapperError.incompleteMessage(reason: "Last chunk was not empty")
        }

        let messageData = body.dropLast(messageTerminator.count)

        // Split the incoming data, using \r\n as a delimiter.
        // At this point we have a sequence containing the following repeated subsequences:
        // - the chunk's length in hexadecimal notation
        // - the chunk's content
        let parts = messageData.split(whereSeparator: {
            $0 == UInt8(0x0A) || $0 == UInt8(0x0D)
        })

        var result = Data()

        // Walk through each chunk's length & content pair, checking if the expected length
        // is valid.
        for index in stride(from: parts.startIndex, to: parts.endIndex, by: 2) {
            let chunkLength = try decodeChunkLength(data: Data(parts[index]))
            let chunkData = Data(parts[index + 1])

            guard chunkLength - 1 == chunkData.count else {
                throw HTTPMessageWrapperError.decodingError(reason: "Invalid chunk length (expected \(chunkLength - 1), got \(chunkData.count))")
            }

            result.append(chunkData)
        }

        return result
    }

    static func createEmptyMessage() -> CFHTTPMessage {
        return CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false).takeRetainedValue()
    }
}

struct Request: HTTPRequestWrapper {
    var httpVersion: String
    var headers: [String: String]
    var body: Data
    var url: URL
    var method: String

    init() {
        self.httpVersion = ""
        self.headers = [:]
        self.body = Data()
        self.url = URL(string: "/")!
        self.method = ""
    }

    init(httpVersion: String, headers: [String: String], body: Data, url: URL, method: String) {
        self.httpVersion = httpVersion
        self.headers = headers
        self.body = body
        self.url = url
        self.method = method
    }

    func serialized() throws -> Data {
        let message = CFHTTPMessageCreateRequest(
            kCFAllocatorDefault,
            method as CFString,
            url as CFURL,
            httpVersion as CFString
        ).takeRetainedValue()

        for (name, value) in headers {
            CFHTTPMessageSetHeaderFieldValue(message, name as CFString, value as CFString)
        }

        guard let serializedMessage = CFHTTPMessageCopySerializedMessage(message) else {
            throw HTTPMessageWrapperError.encodingError(reason: "Could not serialize message")
        }

        return serializedMessage.takeRetainedValue() as Data
    }
}

struct Response: HTTPResponseWrapper {
    var httpVersion: String
    var headers: [String: String]
    var body: Data
    var statusLine: String
    var statusCode: Int

    init() {
        self.httpVersion = ""
        self.headers = [:]
        self.body = Data()
        self.statusLine = ""
        self.statusCode = 0
    }

    init(httpVersion: String, headers: [String: String], body: Data, statusLine: String, statusCode: Int) {
        self.httpVersion = httpVersion
        self.headers = headers
        self.body = body
        self.statusLine = statusLine
        self.statusCode = statusCode
    }

    func serialized() throws -> Data {
        let message = CFHTTPMessageCreateResponse(
            kCFAllocatorDefault,
            statusCode as CFIndex,
            statusLine as CFString,
            httpVersion as CFString
        ).takeRetainedValue()

        guard let serializedMessage = CFHTTPMessageCopySerializedMessage(message) else {
            throw HTTPMessageWrapperError.encodingError(reason: "Could not serialize message")
        }

        return serializedMessage.takeRetainedValue() as Data
    }
}
