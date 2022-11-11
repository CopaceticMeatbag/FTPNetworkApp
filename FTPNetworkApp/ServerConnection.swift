//
//  ServerConnection.swift
//  FTPNetworkApp
//
//  Created by MOH on 18/10/2022.
//

import Foundation
import Network

class ServerConnection {
    //The TCP maximum package size is 64K 65536
    let MTU = 65536
    
    private static var nextID: Int = 0
    let connection: NWConnection
    let id: Int
    let dataAll : [UInt8]
    
    init(nwConnection: NWConnection) {
        connection = nwConnection
        id = ServerConnection.nextID
        ServerConnection.nextID += 1
        dataAll = []
    }
    
    var didStopCallback: ((Error?) -> Void)? = nil
    
    func start() {
        print("connection \(id) will start")
        connection.stateUpdateHandler = self.stateDidChange(to:)
        setupReceive()
        connection.start(queue: .main)
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            print("connection \(id) ready")
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }

    private func getHost() ->  NWEndpoint.Host? {
        switch connection.endpoint {
        case .hostPort(let host , _):
            return host
        default:
            return nil
        }
    }
    
    private func setupReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: MTU) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                switch self.id {
                case 1000:
                    print("test")
                    //keep += our data to an obj while isComplete is false (assume finack)
                default:
                    let message = String(data: data, encoding: .utf8)
                    print("Received data:\(String(data: data, encoding: .utf8) ?? "")")
                    print("Msg: \(message ?? "")")
                    switch message {
                    case _ where message!.contains("USER"):
                        print("User received, password plz")
                        self.send(data: "331 Password Required\r\n".data(using: .utf8)!)
                    case _ where message!.contains("PASS"):
                        print("Password good to go!")
                        self.send(data: "230 Logged On\r\n".data(using: .utf8)!)
                    case _ where message!.contains("PWD"):
                        print("Current DIR")
                        self.send(data: "257 \"/\"\r\n".data(using: .utf8)!)
                    case _ where message!.contains("SYST"):
                        print("System")
                        self.send(data: "215 Kym's iPhoneFTP\r\n".data(using: .utf8)!)
                    case _ where message!.contains("FEAT"):
                        print("Feat")
                        self.send(data: "502 NO\r\n".data(using: .utf8)!)
                    case _ where message!.contains("TYPE"):
                        print("Setting binary")
                        self.send(data: "200 Type set to Binary\r\n".data(using: .utf8)!)
                    case _ where message!.contains("PASV"):
                        print("Entering PASV")
                        let ip = self.getIPAddress().replacingOccurrences(of: ".", with: ",")
                        self.send(data: "227 Entering PASV Mode (\(ip),30,32)\r\n".data(using: .utf8)!)
                    //case _ where message!.contains("EPSV"):
                    //      print("Entering EPSV")
                    //     self.send(data: "229 Entering ESP Mode (|||\(32*256+30)|)\r\n".data(using: .utf8)!)
                    case _ where message!.contains("CWD"):
                        print("Setting binary")
                        self.send(data: "250 CWD success\r\n".data(using: .utf8)!)
                    case _ where message!.contains("STOR"):
                        print("Receiving img")
                        self.send(data: "150 Starting data transfer\r\n".data(using: .utf8)!)
                    case _ where message!.contains("NLST"):
                        print("Send data listing on data conn RUH ROHHH")
                        self.send(data: "150 Opening data channel\r\n".data(using: .utf8)!)
                        //add 226 success transfer on completion of data send/receives.
                    case _ where message!.contains("QUIT"):
                        print("Quitting")
                        self.send(data: "221 Goodbye\r\n".data(using: .utf8)!)
                    default:
                        print("Default case!")
                        self.send(data: "200 Ok\r\n".data(using: .utf8)!)
                    }
                }
            }
            
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                self.connectionDidFail(error: error)
            } else {
                self.setupReceive()
            }
        }
    }

    
    func send(data: Data) {
        self.connection.send(content: data, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            print("connection \(self.id) did send, data: \(data as NSData)")
        }))
    }
    
    func stop() {
        print("connection \(id) will stop")
    }
    
    func getIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface!.ifa_name))
                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address ?? ""
    }
    
    private func connectionDidFail(error: Error) {
        print("connection \(id) did fail, error: \(error)")
        stop(error: error)
    }
    
    private func connectionDidEnd() {
        print("connection \(id) did end")
        stop(error: nil)
    }
    
    private func stop(error: Error?) {
        connection.stateUpdateHandler = nil
        connection.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
}
