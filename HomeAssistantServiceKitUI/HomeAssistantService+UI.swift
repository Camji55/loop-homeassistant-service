//
//  HomeAssistantService+UI.swift
//  HomeAssistantServiceKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import HomeAssistantServiceKit

extension HomeAssistantService: ServiceUI {

    public static var image: UIImage? {
        return UIImage(systemName: "house.fill")
    }

    public static func setupViewController(colorPalette: LoopUIColorPalette, pluginHost: PluginHost) -> SetupUIResult<ServiceViewController, ServiceUI> {
        return .userInteractionRequired(HomeAssistantServiceNavigationController(service: HomeAssistantService(), forCreation: true, colorPalette: colorPalette))
    }

    public func settingsViewController(colorPalette: LoopUIColorPalette) -> ServiceViewController {
        return HomeAssistantServiceNavigationController(service: self, forCreation: false, colorPalette: colorPalette)
    }
}
