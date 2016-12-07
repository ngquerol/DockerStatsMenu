//
//  UnixClientSocket.swift
//  DockerStats
//
//  Created by Nicolas Gaulard-Querol on 14/11/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Darwin
import Foundation

enum ClientSocketError: Error, CustomStringConvertible {
    case creationFailed(code: errno_t)
    case connectionFailed(code: errno_t)
    case closeFailed(code: errno_t)
    case readFailed(code: errno_t)
    case writeFailed(code: errno_t)
    case unknownError()

    private func errnoString(_ code: errno_t) -> String {
        return String(cString: strerror(code))
    }

    var description: String {
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

    var localizedDescription: String {
        return description
    }
}

class UnixClientSocket {
    private static let socketQueue = DispatchQueue(label: "fr.ngquerol.dockerstatsmenu.socketqueue")

    var readEventHandler: ((Data?, Error?) -> Void)? {
        didSet {
            guard let readHandler = self.readEventHandler else { return }

            readEventSource.setEventHandler(qos: .utility, flags: []) {
                self.read(completion: readHandler)
            }
        }
    }

    private let fileDescriptor: Int32

    private let socketPath: String

    private let socketChannel: DispatchIO

    private let readEventSource: DispatchSourceRead

    init(path: String) {
        socketPath = path

        fileDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)

        socketChannel = DispatchIO(
            type: .stream,
            fileDescriptor: fileDescriptor,
            queue: UnixClientSocket.socketQueue
        ) { errCode in
            if errCode != 0 {
                NSLog(ClientSocketError.closeFailed(code: errCode).description)
            }
        }

        socketChannel.setLimit(lowWater: 1)

        readEventSource = DispatchSource.makeReadSource(
            fileDescriptor: fileDescriptor,
            queue: UnixClientSocket.socketQueue
        )

        readEventSource.setCancelHandler {
            self.socketChannel.close(flags: .stop)
        }
    }

    func close() {
        readEventSource.cancel()
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

        readEventSource.activate()
    }

    func read(completion: @escaping (Data?, Error?) -> Void) {
        socketChannel.read(
            offset: 0,
            length: SSIZE_MAX,
            queue: UnixClientSocket.socketQueue
        ) { _, data, error in
            guard error == 0, let data = data, data.count > 0 else {
                return completion(nil, ClientSocketError.readFailed(code: error))
            }

            let readData = data.withUnsafeBytes { dataPtr in
                Data(buffer: UnsafeBufferPointer<UInt8>(start: dataPtr, count: data.count))
            }

            completion(readData, nil)
        }
    }

    func write(data: Data, completion: @escaping (Error?) -> Void) {
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
        self.init(sun_len: UInt8(MemoryLayout<sockaddr_un>.stride),
                  sun_family: sa_family_t(AF_UNIX),
                  sun_path: (0, 0, 0, 0, 0, 0, 0, 0,
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
                             0, 0, 0, 0, 0, 0, 0, 0))

        let sunPathBuffer = UnsafeMutableBufferPointer<Int8>(
            start: &sun_path.0,
            count: MemoryLayout.stride(ofValue: sun_path)
        )
        
        for (i, pathByte) in path.utf8CString.enumerated() {
            sunPathBuffer[i] = pathByte
        }
    }
}
