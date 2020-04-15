//
// This file is part of awesome Puree log agregator
// https://github.com/cookpad/Puree-Swift
//
import Foundation

public protocol DateProvider {
    var now: Date { get }
}

public struct DefaultDateProvider: DateProvider {
    public init() { }
    public var now: Date {
        return Date()
    }
}
