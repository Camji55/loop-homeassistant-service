//
//  OSLog.swift
//  HomeAssistantServiceKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import os.log

extension OSLog {
    convenience init(category: String) {
        self.init(subsystem: "com.loopkit.HomeAssistantServiceKit", category: category)
    }

    func debug(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .debug, args)
    }

    func `default`(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .default, args)
    }

    func error(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .error, args)
    }

    private func log(_ message: StaticString, type: OSLogType, _ args: [CVarArg]) {
        switch args.count {
        case 0:
            os_log(message, log: self, type: type)
        case 1:
            os_log(message, log: self, type: type, args[0])
        case 2:
            os_log(message, log: self, type: type, args[0], args[1])
        case 3:
            os_log(message, log: self, type: type, args[0], args[1], args[2])
        default:
            os_log(message, log: self, type: type, args)
        }
    }
}
