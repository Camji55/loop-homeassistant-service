//
//  HomeAssistantClient.swift
//  HomeAssistantServiceKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import os.log

public enum HomeAssistantClientError: LocalizedError {
    case notConfigured
    case invalidResponse(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return NSLocalizedString("No webhook URL is configured.", comment: "Error when the Home Assistant webhook URL is missing")
        case .invalidResponse(let statusCode):
            return String(format: NSLocalizedString("Home Assistant returned status code %d.", comment: "Error when the webhook returns a non-2xx status"), statusCode)
        }
    }
}

enum HomeAssistantDateFormatter {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func string(from date: Date) -> String {
        return formatter.string(from: date)
    }
}

final class HomeAssistantClient {

    private let session = URLSession(configuration: .ephemeral)

    private let log = OSLog(category: "HomeAssistantClient")

    func post(payload: [String: Any], to url: URL, completion: @escaping (Error?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(error)
            return
        }

        let task = session.dataTask(with: request) { [log] _, response, error in
            if let error = error {
                log.error("Webhook POST failed: %{public}@", String(describing: error))
                completion(error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                log.error("Webhook POST returned status %d", statusCode)
                completion(HomeAssistantClientError.invalidResponse(statusCode: statusCode))
                return
            }
            completion(nil)
        }
        task.resume()
    }
}
