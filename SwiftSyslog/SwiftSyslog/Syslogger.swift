//
//  Syslogger.swift
//
//  https://github.com/pykaso/SwiftSyslog
//  Created by Lukas Gergel on 15/04/2020.
//
import CocoaAsyncSocket
import UIKit

class TcpDelegate: NSObject, GCDAsyncSocketDelegate {
    #if DEBUG
        func socket(_ sock: GCDAsyncSocket, didConnectTo url: URL) {
            print("⭐ RemoteLogger didConnectTo \(url)")
        }

        func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
            print("⭐ RemoteLogger didConnectTo \(host):\(port)")
        }

        func socketDidSecure(_ sock: GCDAsyncSocket) {
            print("⭐ RemoteLogger did sucessfully secure the connection.")
        }

        func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
            print("☠️ RemoteLogger didDisconnect with error: \(String(describing: err))")
        }
    #endif

    func socket(_ sock: GCDAsyncSocket, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true) // Trust all the things!!
    }
}

public class Syslogger: BufferedOutput {
    let host: String
    let port: Int
    let useTLS: Bool

    private var tcpSocket: GCDAsyncSocket!
    private let tcpDelegate: TcpDelegate = TcpDelegate()
    private let sdkVersion = "0.1"
    private let sdkIdentification = "syslogger-ios"
    private let token: String
    private let installIDKey = "syslogger.install.id"

    var userInfo: String?

    var deviceInfo: String {
        UIDevice.modelName.withoutSpaces
    }

    var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    var bundleID: String {
        Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
    }

    var applicationInfo: String {
        "\(bundleID)/\(version).\(buildNumber)"
    }

    var installID: String {
        if UserDefaults.standard.string(forKey: installIDKey) == nil {
            let uuid = UUID()
            UserDefaults.standard.set(uuid.uuidString, forKey: installIDKey)
        }
        return UserDefaults.standard.string(forKey: installIDKey) ?? ""
    }

    var clientCertificateURL: URL? {
        didSet {
            if let url = clientCertificateURL {
                identity = loadIdentity(url: url)
            }
        }
    }

    var identity: SecIdentity?

    public required init(logStore: LogStore, host: String, port: Int, useTLS: Bool = false, token: String, clientCertificateURL: URL? = nil) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.token = token
        self.clientCertificateURL = clientCertificateURL
        super.init(logStore: logStore)

        if let url = clientCertificateURL {
            identity = loadIdentity(url: url)
        }
    }

    func write(_ severity: Rfc5424LogMessage.SyslogSeverity, message: String) {
        var extended: [String: String] = [
            "token": token,
            "device": deviceInfo,
            "install": installID,
        ]
        if let userInfo = userInfo {
            extended["uid"] = userInfo
        }
        let metadata = Rfc5424LogMessage.MessageMetadata(severity: severity, date: .init(),
                                                         application: applicationInfo,
                                                         hostname: "\(sdkIdentification);\(sdkVersion)")
        let structured = Rfc5424LogMessage.StructuredPart(extended)
        let message = Rfc5424LogMessage(metadata: metadata, structured: structured, message: message)
        emit(log: LogEntry(tag: ".", userData: message.asData()))
    }

    public override func write(_ chunk: BufferedOutput.Chunk, completion: @escaping (Bool) -> Void) {
        if tcpSocket == nil {
            let socket = GCDAsyncSocket(delegate: tcpDelegate, delegateQueue: DispatchQueue(label: "logger.tcp.queue", qos: .background))
            tcpSocket = socket
        }

        if !tcpSocket.isConnected {
            do {
                try tcpSocket.connect(toHost: host, onPort: UInt16(port))
                if useTLS {
                    var settings: [String: NSObject] = [:]
                    if let identity = identity {
                        settings[kCFStreamSSLCertificates as String] = NSArray(array: [identity])
                    }
                    tcpSocket.startTLS(settings)
                }
            } catch {
                print("💩 connection to syslog server failed. \(error)")
                completion(false)
                return
            }
        }

        for entry in chunk.logs {
            if let data = entry.userData {
                tcpSocket.write(data, withTimeout: 10, tag: 1)
            }
        }
        // this is naive implementation. not waiting for all writes complete, just assume it's ok
        completion(true)
    }

    func loadIdentity(url: URL) -> SecIdentity {
        do {
            let p12 = try Data(contentsOf: url) as CFData
            let options = [kSecImportExportPassphrase as String: ""] as CFDictionary

            var rawItems: CFArray?

            guard SecPKCS12Import(p12, options, &rawItems) == errSecSuccess else {
                fatalError("Error in p12 import")
            }

            let items = rawItems as! Array<Dictionary<String, Any>>
            let identity = items[0][kSecImportItemIdentity as String] as! SecIdentity

            return identity
        } catch {
            fatalError("Could not create client certificate")
        }
    }
}
