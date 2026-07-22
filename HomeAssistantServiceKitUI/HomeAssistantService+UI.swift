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

extension HomeAssistantService: @retroactive ServiceUI {

    public static var image: UIImage? {
        return UIImage(named: "home-assistant", in: Bundle(for: HomeAssistantServiceNavigationController.self), compatibleWith: nil)
    }

    public static func setupViewController(colorPalette: LoopUIColorPalette, pluginHost: any PluginHost, allowDebugFeatures: Bool) -> SetupUIResult<any ServiceViewController, any ServiceUI> {
        return .userInteractionRequired(HomeAssistantServiceNavigationController(service: HomeAssistantService(), forCreation: true, colorPalette: colorPalette))
    }

    public func settingsViewController(colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> any ServiceViewController {
        return HomeAssistantServiceNavigationController(service: self, forCreation: false, colorPalette: colorPalette)
    }
}
