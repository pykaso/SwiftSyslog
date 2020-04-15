//
//  Rfc5424LogMessage.swift
//
//  https://github.com/pykaso/SwiftSyslog
//  Created by Lukas Gergel on 15/04/2020.
//

import Foundation
import UIKit

public struct Rfc5424LogMessage {
    // See https://tools.ietf.org/html/rfc5424#section-6.2.3
    private static let defaultDateFormat: String = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
    private static let posixLocaleID: String = "en_US_POSIX"

    /// Severity level to attach to log message.
    ///
    /// See:
    ///
    /// - https://en.wikipedia.org/wiki/Syslog#Severity_level
    /// - https://tools.ietf.org/html/rfc5424#section-6.2.1
    ///
    /// for full documentation.
    public enum SyslogSeverity: Int {
        case emergency = 0
        case alert
        case critical
        case error
        case warning
        case notice
        case info
        case debug
    }

    /// Facility code to attach to log message.
    ///
    /// See:
    ///
    /// - https://en.wikipedia.org/wiki/Syslog#Facility
    /// - https://tools.ietf.org/html/rfc5424#section-6.2.1
    ///
    /// for full documentation.
    public enum SyslogFacility: Int {
        case kernel = 0
        case user
        case mail
        case daemon
        case auth
        case syslog
        case lpr
        case news
        case uucp
        case clock
        case authpriv
        case ftp
        case ntp
        case audit
        case alert
        case cron
        case local0
        case local1
        case local2
        case local3
        case local4
        case local5
        case local6
        case local7
    }

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Self.posixLocaleID)
        formatter.dateFormat = Self.defaultDateFormat
        formatter.timeZone = .current
        return formatter
    }()

    let metadata: MessageMetadata
    let structured: StructuredPart
    let message: String

    /// SocketLogDetails is a struct used to attach metadata for configuring each
    /// syslog message.
    ///
    /// See https://tools.ietf.org/html/rfc5424#page-8 for further details on
    /// supported fields.
    public struct MessageMetadata {
        let priority: Int
        let date: Date
        let hostname: String
        let application: String
        let extended: [String: String]?
        private let facility: SyslogFacility = .user

        init(severity: SyslogSeverity = .info, date: Date, application: String, hostname: String, extended: [String: String]? = nil) {
            priority = severity.rawValue + facility.rawValue * 8
            self.date = date
            self.application = application.withoutSpaces
            self.hostname = hostname.withoutSpaces
            self.extended = extended
        }

        func formatted(withFormatter dateFormatter: DateFormatter) -> String {
            return "<\(priority)>1 \(dateFormatter.string(from: date)) \(hostname) \(application) - -"
        }
    }

    public struct StructuredPart {
        let data: [String: String]

        init(_ data: [String: String]) {
            self.data = data
        }

        func formatted() -> String {
            "[meta \(data.map { "\($0.0)=\"\($0.1)\"" }.joined(separator: " "))]"
        }
    }

    init(metadata: MessageMetadata, structured: StructuredPart, message: String) {
        self.metadata = metadata
        self.structured = structured
        self.message = message.inlineSafeValue
    }

    func formatted() -> String {
        return "\(metadata.formatted(withFormatter: dateFormatter)) \(structured.formatted()) \(message)\n"
    }

    func asData() -> Data? {
        formatted().data(using: .utf8)
    }
}
