//
//  Server.swift
//  FTPNetworkApp
//
//  Created by MOH on 18/10/2022.
//

import Foundation
import Network

class Server {
    let port: NWEndpoint.Port
    let dataport: NWEndpoint.Port
    let listener: NWListener
    let datalistener: NWListener
    let p1,p2: UInt16

    private var connectionsByID: [Int: ServerConnection] = [:]

    init(port: UInt16) {
        //self.p1 = UInt16.random(in: 30..<50)
        //self.p2 = UInt16.random(in: 30..<50)
        self.p1 = UInt16.init(30)
        self.p2 = UInt16.init(32)
        self.port = NWEndpoint.Port(rawValue: port)!
        self.dataport = NWEndpoint.Port(rawValue: self.p1*256+self.p2)!
        listener = try! NWListener(using: .tcp, on: self.port)
        datalistener = try! NWListener(using: .tcp, on: self.dataport)
    }

    func start() throws {
        print("Server starting...")
        listener.stateUpdateHandler = self.stateDidChange(to:)
        listener.newConnectionHandler = self.didAccept(nwConnection:)
        listener.start(queue: .main)
        datalistener.stateUpdateHandler = self.stateDidChange(to:)
        datalistener.newConnectionHandler = self.didAccept(nwConnection:)
        datalistener.start(queue: .main)
    }

    func stateDidChange(to newState: NWListener.State) {
        switch newState {
        case .ready:
          print("Server ready.")
        case .failed(let error):
            print("Server failure, error: \(error.localizedDescription)")
            exit(EXIT_FAILURE)
        default:
            break
        }
    }

    private func didAccept(nwConnection: NWConnection) {
        let connection = ServerConnection(nwConnection: nwConnection)
        self.connectionsByID[connection.id] = connection
        connection.didStopCallback = { _ in
            self.connectionDidStop(connection)
        }
        connection.start()
        connection.send(data: "220 Welcome \r\n".data(using: .utf8)!)
        print("server did open connection \(connection.id)")
    }

    private func connectionDidStop(_ connection: ServerConnection) {
        self.connectionsByID.removeValue(forKey: connection.id)
        print("server did close connection \(connection.id)")
    }

    private func stop() {
        self.listener.stateUpdateHandler = nil
        self.listener.newConnectionHandler = nil
        self.listener.cancel()
        self.datalistener.stateUpdateHandler = nil
        self.datalistener.newConnectionHandler = nil
        self.datalistener.cancel()
        for connection in self.connectionsByID.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        self.connectionsByID.removeAll()
    }
}
