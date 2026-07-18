//
//  HKUnit.swift
//  HomeAssistantServiceKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import HealthKit

extension HKUnit {
    static let milligramsPerDeciliter: HKUnit = {
        return HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    }()

    static let milligramsPerDeciliterPerMinute: HKUnit = {
        return HKUnit.milligramsPerDeciliter.unitDivided(by: .minute())
    }()
}
