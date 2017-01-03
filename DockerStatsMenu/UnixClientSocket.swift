//
//  UnixClientSocket.swift
//  DockerStats
//
//  Created by Nicolas Gaulard-Querol on 14/11/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Darwin
import Foundation

enum ClientSocketError: Error {
    case creationFailed(code: errno_t)
    case connectionFailed(code: errno_t)
    case closeFailed(code: errno_t)
    case readFailed(code: errno_t)
    case writeFailed(code: errno_t)
    case unknownError()

    fileprivate func errnoString(_ code: errno_t) -> String {
        return String(cString: strerror(code))
    }
}

extension ClientSocketError: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .creationFailed(let code):
            return "client socket creation failed: " + errnoString(code)
        case .connectionFailed(let code):
            return "client socket connection failed: " + errnoString(code)
        case .closeFailed(let code):
            return "client socket close failed: " + errnoString(code)
        case .readFailed(let code):
            return "client socket read failed: " + errnoString(code)
        case .writeFailed(let code):
            return "client socket write failed: " + errnoString(code)
        case .unknownError():
            return "unknown client socket error"
        }
    }
}

class UnixClientSocket {
    private static let socketQueue = DispatchQueue(label: "fr.ngquerol.dockerstatsmenu.socketqueue")

    private var fileDescriptor: Int32

    private let socketPath: String

    private let socketChannel: DispatchIO

    private let readEventSource: DispatchSourceRead

    var isClosed: Bool {
        return fileDescriptor == -1
    }

    var readEventHandler: ((Data?, Error?) -> Void)?

    init(path: String) {
        socketPath = path

        fileDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)

        socketChannel = DispatchIO(
            type: .stream,
            fileDescriptor: fileDescriptor,
            queue: UnixClientSocket.socketQueue
        ) { errCode in
            if errCode != 0 {
                NSLog(ClientSocketError.closeFailed(code: errCode).localizedDescription)
            }
        }

        socketChannel.setLimit(lowWater: 1)

        readEventSource = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor,
                                                        queue: DispatchQueue.global(qos: .utility))
        readEventSource.setEventHandler {
            self.receive { data, error in
                if let readEventHandler = self.readEventHandler {
                    readEventHandler(data, error)
                }
            }
        }
    }

    deinit {
        close()
    }

    func close() {
        readEventHandler = nil
        readEventSource.cancel()
        socketChannel.close(flags: .stop)
        fileDescriptor = -1
    }

    func connect() throws {
        var addr_un = sockaddr_un(path: socketPath)

        let (addr, addr_len) = withUnsafePointer(to: &addr_un) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                ($0, socklen_t($0.pointee.sa_len))
            }
        }

        if Darwin.connect(fileDescriptor, addr, addr_len) == -1 {
            throw ClientSocketError.connectionFailed(code: errno)
        }

        readEventSource.resume()
    }

    func receive(completion: @escaping (Data?, Error?) -> Void) {
        self.socketChannel.read(
            offset: 0,
            length: SSIZE_MAX,
            queue: UnixClientSocket.socketQueue
        ) { done, data, error in
            guard error == 0, let data = data, data.count > 0 else {
                return completion(nil, ClientSocketError.readFailed(code: error))
            }

            let readData = data.withUnsafeBytes { dataPtr in
                Data(buffer: UnsafeBufferPointer<UInt8>(start: dataPtr, count: data.count))
            }

            completion(readData, nil)
        }
    }

    func send(data: Data, completion: @escaping (Error?) -> Void) {
        let dispatchData = data.withUnsafeBytes {
            DispatchData(bytes: UnsafeBufferPointer<UInt8>(start: $0, count: data.count))
        }

        socketChannel.write(
            offset: 0,
            data: dispatchData,
            queue: UnixClientSocket.socketQueue
        ) { _, data, error in
            guard data == nil, error == 0 else {
                return completion(error == 0 ? ClientSocketError.unknownError() : ClientSocketError.writeFailed(code: errno))
            }

            completion(nil)
        }
    }
}

fileprivate extension sockaddr_un {
    
    init(path: String) {
        self.init(
            sun_len: UInt8(MemoryLayout<sockaddr_un>.stride),
            sun_family: sa_family_t(AF_UNIX),
            sun_path: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0
            )
        )

        let sunPathBuffer = UnsafeMutableBufferPointer<Int8>(
            start: &sun_path.0,
            count: MemoryLayout.stride(ofValue: sun_path)
        )

        for (i, pathByte) in path.utf8CString.enumerated() {
            sunPathBuffer[i] = pathByte
        }
    }
}
