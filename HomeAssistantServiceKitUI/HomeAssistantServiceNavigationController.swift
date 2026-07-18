//
//  HomeAssistantServiceNavigationController.swift
//  HomeAssistantServiceKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import HomeAssistantServiceKit

final class HomeAssistantServiceNavigationController: UINavigationController, ServiceOnboarding, CompletionNotifying {

    weak var serviceOnboardingDelegate: ServiceOnboardingDelegate?
    weak var completionDelegate: CompletionDelegate?

    init(service: HomeAssistantService, forCreation: Bool, colorPalette: LoopUIColorPalette) {
        let viewModel = HomeAssistantSettingsViewModel(service: service, forCreation: forCreation)
        let view = HomeAssistantSettingsView(viewModel: viewModel)
        super.init(rootViewController: UIHostingController(rootView: view))

        viewModel.didSave = { [weak self] service in
            guard let self = self else { return }
            if forCreation {
                self.serviceOnboardingDelegate?.serviceOnboarding(didCreateService: service)
                service.completeOnboard()
                self.serviceOnboardingDelegate?.serviceOnboarding(didOnboardService: service)
            } else {
                service.completeUpdate()
            }
            self.completionDelegate?.completionNotifyingDidComplete(self)
        }

        viewModel.didDelete = { [weak self] service in
            guard let self = self else { return }
            service.completeDelete()
            self.completionDelegate?.completionNotifyingDidComplete(self)
        }

        viewModel.didCancel = { [weak self] in
            guard let self = self else { return }
            self.completionDelegate?.completionNotifyingDidComplete(self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
