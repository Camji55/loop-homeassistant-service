//
//  HomeAssistantServiceKitPlugin.swift
//  HomeAssistantServiceKitPlugin
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import os.log
import LoopKitUI
import HomeAssistantServiceKit
import HomeAssistantServiceKitUI

class HomeAssistantServiceKitPlugin: NSObject, ServiceUIPlugin {
    private let log = OSLog(subsystem: "com.loopkit.HomeAssistantServiceKitPlugin", category: "HomeAssistantServiceKitPlugin")

    public var serviceType: ServiceUI.Type? {
        return HomeAssistantService.self
    }

    override init() {
        super.init()
        os_log("Instantiated", log: log, type: .default)
    }
}
