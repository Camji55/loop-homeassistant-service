//
//  HomeAssistantService.swift
//  HomeAssistantServiceKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import os.log

public final class HomeAssistantService: Service {

    public static let pluginIdentifier = "HomeAssistantService"

    public static let localizedTitle = NSLocalizedString("Home Assistant", comment: "The title of the Home Assistant service")

    public weak var serviceDelegate: ServiceDelegate?

    public weak var stateDelegate: StatefulPluggableDelegate?

    public var webhookURL: URL?

    public var isOnboarded: Bool

    let client = HomeAssistantClient()

    private let log = OSLog(category: "HomeAssistantService")

    public init() {
        self.isOnboarded = false
    }

    public required init?(rawState: RawStateValue) {
        self.isOnboarded = rawState["isOnboarded"] as? Bool ?? true
        restoreCredentials()
    }

    public var rawState: RawStateValue {
        return ["isOnboarded": isOnboarded]
    }

    public var hasConfiguration: Bool { webhookURL != nil }

    public func completeCreate() {
        saveCredentials()
    }

    public func completeOnboard() {
        isOnboarded = true
        saveCredentials()
        stateDelegate?.pluginDidUpdateState(self)
    }

    public func completeUpdate() {
        saveCredentials()
        stateDelegate?.pluginDidUpdateState(self)
    }

    public func completeDelete() {
        clearCredentials()
        stateDelegate?.pluginWantsDeletion(self)
    }

    private func saveCredentials() {
        try? KeychainManager().setHomeAssistantWebhookURL(webhookURL)
    }

    private func restoreCredentials() {
        webhookURL = KeychainManager().getHomeAssistantWebhookURL()
    }

    private func clearCredentials() {
        try? KeychainManager().setHomeAssistantWebhookURL(nil)
    }

    /// Sends a minimal payload so the user can verify connectivity from the settings screen.
    public func verifyConnection(completion: @escaping (Error?) -> Void) {
        guard let webhookURL = webhookURL else {
            completion(HomeAssistantClientError.notConfigured)
            return
        }
        client.post(payload: ["timestamp": HomeAssistantDateFormatter.string(from: Date())], to: webhookURL, completion: completion)
    }
}

private let homeAssistantAccount = "HomeAssistantWebhook"

extension KeychainManager {
    func setHomeAssistantWebhookURL(_ url: URL?) throws {
        let credentials: InternetCredentials?
        if let url = url {
            credentials = InternetCredentials(username: homeAssistantAccount, password: "webhook", url: url)
        } else {
            credentials = nil
        }
        try replaceInternetCredentials(credentials, forAccount: homeAssistantAccount)
    }

    func getHomeAssistantWebhookURL() -> URL? {
        return (try? getInternetCredentials(account: homeAssistantAccount))?.url
    }
}
