//
// This file is based on awesome Puree log agregator
// https://github.com/cookpad/Puree-Swift
//

import Foundation

public protocol Output {
    func start()
    func resume()
    func suspend()
    func emit(log: LogEntry)

}

public extension Output {
    func start() {
    }

    func resume() {
    }

    func suspend() {
    }
}
