//
//  Syslogger.swift
//
//  https://github.com/pykaso/SwiftSyslog
//  Created by Lukas Gergel on 15/04/2020.
//
import CocoaAsyncSocket
import UIKit

class TcpDelegate: NSObject, GCDAsyncSocketDelegate {
    var debugMode: Bool = false
    
    func socket(_ sock: GCDAsyncSocket, didConnectTo url: URL) {
        if debugMode {
            print("⭐ Syslogger didConnectTo \(url)")
        }
    }

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        if debugMode {
            print("⭐ Syslogger didConnectTo \(host):\(port)")
        }
    }

    func socketDidSecure(_ sock: GCDAsyncSocket) {
        if debugMode {
            print("⭐ Syslogger did sucessfully secure the connection.")
        }
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if debugMode {
            print("☠️ Syslogger didDisconnect with error: \(String(describing: err))")
        }
    }
}

public class Syslogger: BufferedOutput {
    let host: String
    let port: Int
    let useTLS: Bool

    private var tcpSocket: GCDAsyncSocket!
    private let tcpDelegate: TcpDelegate = TcpDelegate()
    private let sdkIdentification = "syslogger-ios"
    private let apiKey: String
    private let installIDKey = "syslogger.install.id"

    private var sdkVersion: String {
        let bundle = Bundle.init(for: Syslogger.self)
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return "\(version)"
    }
    
    public var debugMode: Bool = false {
        didSet {
            tcpDelegate.debugMode = debugMode
        }
    }
    
    public var userInfo: String?
    
    public var deviceInfo: String {
        UIDevice.modelName.withoutSpaces
    }

    public var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    public var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    public var bundleID: String {
        Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
    }

    public var applicationInfo: String {
        "\(bundleID)/\(version).\(buildNumber)"
    }

    public var installID: String {
        if UserDefaults.standard.string(forKey: installIDKey) == nil {
            let uuid = UUID()
            UserDefaults.standard.set(uuid.uuidString, forKey: installIDKey)
        }
        return UserDefaults.standard.string(forKey: installIDKey) ?? ""
    }

    public var clientCertificateURL: URL? {
        didSet {
            if let url = clientCertificateURL {
                identity = loadIdentity(url: url)
            }
        }
    }

    private var identity: SecIdentity?

    /// Syslogger framework init
    ///
    /// - Parameters:
    ///     - logStore: Temporary log storage. Logs are store here fist, then will be send to syslog server
    ///     - host: The syslog server hostname
    ///     - port: The syslog server port number
    ///     - useTLS: Connect to the syslog server via TLS secured connection
    ///     - apiKey: Api key stored on the syslog server
    public required init(logStore: LogStore, host: String, port: Int, useTLS: Bool = true, apiKey: String, clientCertificateURL: URL? = nil) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.apiKey = apiKey
        self.clientCertificateURL = clientCertificateURL
        super.init(logStore: logStore)

        if let url = clientCertificateURL {
            identity = loadIdentity(url: url)
        }
    }

    /// Optional syslogger init with default FileLogStore
    ///
    /// - Parameters:
    ///     - logStore: Temporary log storage. Logs are store here fist, then will be send to syslog server
    ///     - host: The syslog server hostname
    ///     - port: The syslog server port number
    ///     - useTLS: Connect to the syslog server via TLS secured connection
    ///     - apiKey: Api key stored on the syslog server
    public convenience init(host: String, port: Int, useTLS: Bool = true, apiKey: String, clientCertificateURL: URL? = nil) {
        let logStore = FileLogStore()
        try? logStore.prepare()
        self.init(logStore: logStore, host: host, port: port, useTLS: useTLS, apiKey: apiKey, clientCertificateURL: clientCertificateURL)
    }

    public func write(_ severity: Rfc5424LogMessage.SyslogSeverity, message: String) {
        var extended: [String: String] = [
            "token": apiKey,
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
                if debugMode {
                    print("💩 connection to syslog server failed. \(error)")
                }
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
