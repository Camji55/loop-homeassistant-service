//
//  HomeAssistantSettingsView.swift
//  HomeAssistantServiceKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HomeAssistantServiceKit

final class HomeAssistantSettingsViewModel: ObservableObject {

    let service: HomeAssistantService
    let forCreation: Bool

    @Published var urlText: String
    @Published var isVerifying: Bool = false
    @Published var verificationResult: String?

    var didSave: ((HomeAssistantService) -> Void)?
    var didDelete: ((HomeAssistantService) -> Void)?
    var didCancel: (() -> Void)?

    init(service: HomeAssistantService, forCreation: Bool) {
        self.service = service
        self.forCreation = forCreation
        self.urlText = service.webhookURL?.absoluteString ?? ""
    }

    var enteredURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            return nil
        }
        return url
    }

    var canSave: Bool { enteredURL != nil }

    func save() {
        guard let url = enteredURL else { return }
        service.webhookURL = url
        if forCreation {
            service.completeCreate()
        }
        didSave?(service)
    }

    func verify() {
        guard let url = enteredURL else { return }
        isVerifying = true
        verificationResult = nil

        let previousURL = service.webhookURL
        service.webhookURL = url
        service.verifyConnection { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.service.webhookURL = previousURL
                self.isVerifying = false
                if let error = error {
                    self.verificationResult = String(format: NSLocalizedString("Connection failed: %@", comment: "Format for webhook verification failure"), error.localizedDescription)
                } else {
                    self.verificationResult = NSLocalizedString("Connected!", comment: "Message shown when webhook verification succeeds")
                }
            }
        }
    }

    func delete() {
        didDelete?(service)
    }
}

struct HomeAssistantSettingsView: View {

    @ObservedObject var viewModel: HomeAssistantSettingsViewModel

    var body: some View {
        Form {
            Section(
                header: Text(NSLocalizedString("Webhook URL", comment: "Section title for webhook URL")),
                footer: Text(NSLocalizedString("Add the Loop integration in Home Assistant (Settings → Devices & Services → Add Integration → Loop) and paste the webhook URL it gives you here.", comment: "Instructions for finding the webhook URL"))
            ) {
                TextField("https://homeassistant.local:8123/api/webhook/…", text: $viewModel.urlText)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            Section {
                Button(action: { viewModel.verify() }) {
                    if viewModel.isVerifying {
                        ProgressView()
                    } else {
                        Text(NSLocalizedString("Test Connection", comment: "Button title to test the webhook connection"))
                    }
                }
                .disabled(!viewModel.canSave || viewModel.isVerifying)

                if let verificationResult = viewModel.verificationResult {
                    Text(verificationResult)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            if !viewModel.forCreation {
                Section {
                    Button(action: { viewModel.delete() }) {
                        Text(NSLocalizedString("Delete Service", comment: "Button title to delete the service"))
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationBarTitle(Text(NSLocalizedString("Home Assistant", comment: "Navigation title for Home Assistant settings")))
        .navigationBarItems(
            leading: Button(NSLocalizedString("Cancel", comment: "Cancel button title")) {
                viewModel.didCancel?()
            },
            trailing: Button(NSLocalizedString("Save", comment: "Save button title")) {
                viewModel.save()
            }
            .disabled(!viewModel.canSave)
        )
    }
}
