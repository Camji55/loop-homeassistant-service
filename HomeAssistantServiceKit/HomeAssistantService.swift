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
    
    public let pluginIdentifier = "HomeAssistantService"

    public static let localizedTitle = NSLocalizedString("Home Assistant", comment: "The title of the Home Assistant service")

    /// Identifies which AID app is pushing (e.g. "Loop" or "Trio") so the Home Assistant
    /// integration can tell multiple instances apart. Included in every payload as "source".
    public static let sourceName: String =
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Loop"

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

    /// Pushes an arbitrary payload fragment (see PAYLOAD.md) — for host apps whose data
    /// doesn't come from LoopKit's stores (e.g. Trio's oref determinations). Timestamp and
    /// source are appended automatically.
    public func uploadPayload(_ payload: [String: Any], completion: ((Error?) -> Void)? = nil) {
        guard let webhookURL = webhookURL else {
            completion?(HomeAssistantClientError.notConfigured)
            return
        }
        var payload = payload
        payload["timestamp"] = HomeAssistantDateFormatter.string(from: Date())
        payload["source"] = Self.sourceName
        client.post(payload: payload, to: webhookURL) { error in
            completion?(error)
        }
    }

    /// Sends a minimal payload so the user can verify connectivity from the settings screen.
    public func verifyConnection(completion: @escaping (Error?) -> Void) {
        guard let webhookURL = webhookURL else {
            completion(HomeAssistantClientError.notConfigured)
            return
        }
        client.post(
            payload: [
                "timestamp": HomeAssistantDateFormatter.string(from: Date()),
                "source": Self.sourceName,
            ],
            to: webhookURL,
            completion: completion
        )
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
