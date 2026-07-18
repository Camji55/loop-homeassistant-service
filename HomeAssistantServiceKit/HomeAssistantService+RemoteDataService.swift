//
//  HomeAssistantService+RemoteDataService.swift
//  HomeAssistantServiceKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

extension HomeAssistantService: RemoteDataService {

    public var glucoseDataLimit: Int? { return 500 }
    public var doseDataLimit: Int? { return 500 }
    public var carbDataLimit: Int? { return 500 }
    public var pumpEventDataLimit: Int? { return 500 }
    public var dosingDecisionDataLimit: Int? { return 50 }
    public var settingsDataLimit: Int? { return 100 }
    public var alertDataLimit: Int? { return 100 }

    public func uploadGlucoseData(_ stored: [StoredGlucoseSample], completion: @escaping (Result<Bool, Error>) -> Void) {
        upload(["glucose": stored.map { $0.homeAssistantRepresentation }], isEmpty: stored.isEmpty, completion: completion)
    }

    public func uploadDoseData(created: [DoseEntry], deleted: [DoseEntry], completion: @escaping (Result<Bool, Error>) -> Void) {
        upload(["doses": created.map { $0.homeAssistantRepresentation }], isEmpty: created.isEmpty, completion: completion)
    }

    public func uploadCarbData(created: [SyncCarbObject], updated: [SyncCarbObject], deleted: [SyncCarbObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        let carbs = (created + updated).map { $0.homeAssistantRepresentation }
        upload(["carbs": carbs], isEmpty: carbs.isEmpty, completion: completion)
    }

    public func uploadPumpEventData(_ stored: [PersistedPumpEvent], completion: @escaping (Result<Bool, Error>) -> Void) {
        var payload: [String: Any] = ["pump_events": stored.map { $0.homeAssistantRepresentation }]
        var status: [String: Any] = [:]
        if let lastPrime = stored.filter({ $0.type == .prime }).max(by: { $0.date < $1.date }) {
            status["last_site_change"] = HomeAssistantDateFormatter.string(from: lastPrime.date)
        }
        if let lastRewind = stored.filter({ $0.type == .rewind }).max(by: { $0.date < $1.date }) {
            status["last_reservoir_change"] = HomeAssistantDateFormatter.string(from: lastRewind.date)
        }
        if !status.isEmpty {
            payload["status"] = status
        }
        upload(payload, isEmpty: stored.isEmpty, completion: completion)
    }

    public func uploadDosingDecisionData(_ stored: [StoredDosingDecision], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let latest = stored.max(by: { $0.date < $1.date }) else {
            completion(.success(true))
            return
        }
        var payload: [String: Any] = [:]
        payload["dosing_decision"] = latest.homeAssistantDosingDecision
        payload["status"] = latest.homeAssistantStatus
        upload(payload, isEmpty: false, completion: completion)
    }

    public func uploadSettingsData(_ stored: [StoredSettings], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let latest = stored.max(by: { $0.date < $1.date }) else {
            completion(.success(true))
            return
        }
        let payload: [String: Any] = [
            "status": ["closed_loop": latest.dosingEnabled],
            "settings": latest.homeAssistantRepresentation,
        ]
        upload(payload, isEmpty: false, completion: completion)
    }

    public func uploadTemporaryOverrideData(updated: [TemporaryScheduleOverride], deleted: [TemporaryScheduleOverride], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !updated.isEmpty || !deleted.isEmpty else {
            completion(.success(true))
            return
        }
        let now = Date()
        let active = updated
            .filter { $0.startDate <= now && $0.actualEndDate > now }
            .max(by: { $0.startDate < $1.startDate })
        upload(["override": active?.homeAssistantRepresentation ?? NSNull()], isEmpty: false, completion: completion)
    }

    public func uploadAlertData(_ stored: [SyncAlertObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        upload(["alerts": stored.map { $0.homeAssistantRepresentation }], isEmpty: stored.isEmpty, completion: completion)
    }

    public func uploadCgmEventData(_ stored: [PersistedCgmEvent], completion: @escaping (Result<Bool, Error>) -> Void) {
        var payload: [String: Any] = ["cgm_events": stored.map { $0.homeAssistantRepresentation }]
        if let lastStart = stored.filter({ $0.type == .sensorStart }).max(by: { $0.date < $1.date }) {
            payload["status"] = ["last_sensor_start": HomeAssistantDateFormatter.string(from: lastStart.date)]
        }
        upload(payload, isEmpty: stored.isEmpty, completion: completion)
    }

    public func remoteNotificationWasReceived(_ notification: [String: AnyObject]) async throws {
        // Home Assistant pushes data out of Loop only; remote commands are not supported.
    }

    private func upload(_ payload: [String: Any], isEmpty: Bool, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard hasConfiguration, let webhookURL = webhookURL else {
            completion(.success(true))
            return
        }
        guard !isEmpty else {
            completion(.success(true))
            return
        }

        var payload = payload
        payload["timestamp"] = HomeAssistantDateFormatter.string(from: Date())
        payload["source"] = Self.sourceName

        client.post(payload: payload, to: webhookURL) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(true))
            }
        }
    }
}

private extension HKQuantity {
    var mgdl: Double {
        return doubleValue(for: .milligramsPerDeciliter)
    }
}

private let mgdlPerMinute = HKUnit.milligramsPerDeciliterPerMinute

extension StoredGlucoseSample {
    var homeAssistantRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "date": HomeAssistantDateFormatter.string(from: startDate),
            "value_mgdl": quantity.mgdl,
            "is_calibration": isDisplayOnly,
        ]
        if let trend = trend {
            dict["trend"] = String(describing: trend)
        }
        if let trendRate = trendRate {
            dict["trend_rate_mgdl_per_min"] = trendRate.doubleValue(for: mgdlPerMinute)
        }
        if let device = device, let name = device.name {
            dict["device"] = name
        }
        return dict
    }
}

extension DoseEntry {
    var homeAssistantRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "type": String(describing: type),
            "start_date": HomeAssistantDateFormatter.string(from: startDate),
            "end_date": HomeAssistantDateFormatter.string(from: endDate),
        ]
        switch unit {
        case .units:
            dict["programmed_units"] = programmedUnits
        case .unitsPerHour:
            dict["rate_units_per_hour"] = unitsPerHour
        }
        if let deliveredUnits = deliveredUnits {
            dict["delivered_units"] = deliveredUnits
        }
        if let automatic = automatic {
            dict["automatic"] = automatic
        }
        return dict
    }
}

extension SyncCarbObject {
    var homeAssistantRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "date": HomeAssistantDateFormatter.string(from: startDate),
            "grams": grams,
        ]
        if let absorptionTime = absorptionTime {
            dict["absorption_time_minutes"] = absorptionTime / 60
        }
        if let foodType = foodType {
            dict["food_type"] = foodType
        }
        return dict
    }
}

extension PersistedPumpEvent {
    var homeAssistantRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "date": HomeAssistantDateFormatter.string(from: date),
        ]
        if let type = type {
            dict["type"] = type.rawValue
        }
        if let title = title {
            dict["description"] = title
        }
        return dict
    }
}

extension StoredDosingDecision {
    var homeAssistantDosingDecision: [String: Any] {
        var dict: [String: Any] = [
            "date": HomeAssistantDateFormatter.string(from: date),
        ]
        if let insulinOnBoard = insulinOnBoard {
            dict["insulin_on_board"] = insulinOnBoard.value
        }
        if let carbsOnBoard = carbsOnBoard {
            dict["carbs_on_board"] = carbsOnBoard.value
        }
        if let eventualGlucose = predictedGlucose?.last {
            dict["eventual_glucose_mgdl"] = eventualGlucose.quantity.mgdl
        }
        if let manualBolusRecommendation = manualBolusRecommendation {
            dict["recommended_bolus"] = manualBolusRecommendation.recommendation.amount
        }
        return dict
    }

    var homeAssistantStatus: [String: Any] {
        var dict: [String: Any] = [:]
        if errors.isEmpty {
            dict["last_loop_completed"] = HomeAssistantDateFormatter.string(from: date)
        }
        if let lastReservoirValue = lastReservoirValue {
            dict["reservoir_units"] = lastReservoirValue.unitVolume
        }
        if let pumpManagerStatus = pumpManagerStatus {
            if let pumpBatteryChargeRemaining = pumpManagerStatus.pumpBatteryChargeRemaining {
                dict["pump_battery_percent"] = pumpBatteryChargeRemaining * 100
            }
            if let basalDeliveryState = pumpManagerStatus.basalDeliveryState {
                switch basalDeliveryState {
                case .suspended, .suspending:
                    dict["pump_suspended"] = true
                    dict["basal_rate"] = 0.0
                case .tempBasal(let dose):
                    dict["pump_suspended"] = false
                    dict["basal_rate"] = dose.unitsPerHour
                case .active, .initiatingTempBasal, .cancelingTempBasal, .resuming:
                    dict["pump_suspended"] = false
                }
            }
        }
        return dict
    }
}

extension SyncAlertObject {
    var homeAssistantRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "issued_date": HomeAssistantDateFormatter.string(from: issuedDate),
            "manager_identifier": identifier.managerIdentifier,
            "alert_identifier": identifier.alertIdentifier,
            "interruption_level": interruptionLevel.rawValue,
        ]
        if let content = foregroundContent ?? backgroundContent {
            dict["title"] = content.title
            dict["body"] = content.body
        }
        if let acknowledgedDate = acknowledgedDate {
            dict["acknowledged_date"] = HomeAssistantDateFormatter.string(from: acknowledgedDate)
        }
        if let retractedDate = retractedDate {
            dict["retracted_date"] = HomeAssistantDateFormatter.string(from: retractedDate)
        }
        return dict
    }
}

extension PersistedCgmEvent {
    var homeAssistantRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "date": HomeAssistantDateFormatter.string(from: date),
            "type": type.rawValue,
            "device": deviceIdentifier,
        ]
        if let expectedLifetime = expectedLifetime {
            dict["expected_lifetime_minutes"] = expectedLifetime / 60
        }
        return dict
    }
}

extension StoredSettings {
    var homeAssistantRepresentation: [String: Any] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = controllerTimeZone
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = startOfDay.addingTimeInterval(24 * 60 * 60)

        func minutes(_ date: Date) -> Int {
            return Int(date.timeIntervalSince(startOfDay) / 60)
        }

        var dict: [String: Any] = ["closed_loop": dosingEnabled]
        if let maximumBolus = maximumBolus {
            dict["maximum_bolus"] = maximumBolus
        }
        if let maximumBasalRatePerHour = maximumBasalRatePerHour {
            dict["maximum_basal_rate"] = maximumBasalRatePerHour
        }
        if let suspendThreshold = suspendThreshold {
            dict["suspend_threshold_mgdl"] = suspendThreshold.quantity.doubleValue(for: .milligramsPerDeciliter)
        }
        if let insulinType = insulinType {
            dict["insulin_type"] = String(describing: insulinType)
        }
        if let schedule = basalRateSchedule {
            dict["basal_schedule"] = schedule.between(start: startOfDay, end: endOfDay).map {
                ["start_minutes": minutes($0.startDate), "rate": $0.value]
            }
        }
        if let schedule = carbRatioSchedule {
            dict["carb_ratio_schedule"] = schedule.between(start: startOfDay, end: endOfDay).map {
                ["start_minutes": minutes($0.startDate), "ratio": $0.value]
            }
        }
        if let schedule = insulinSensitivitySchedule {
            let unit = schedule.unit
            dict["insulin_sensitivity_schedule"] = schedule.between(start: startOfDay, end: endOfDay).map {
                [
                    "start_minutes": minutes($0.startDate),
                    "sensitivity_mgdl": HKQuantity(unit: unit, doubleValue: $0.value).mgdl,
                ]
            }
        }
        if let schedule = glucoseTargetRangeSchedule {
            let unit = schedule.unit
            dict["correction_range_schedule"] = schedule.between(start: startOfDay, end: endOfDay).map {
                [
                    "start_minutes": minutes($0.startDate),
                    "lower_mgdl": HKQuantity(unit: unit, doubleValue: $0.value.minValue).mgdl,
                    "upper_mgdl": HKQuantity(unit: unit, doubleValue: $0.value.maxValue).mgdl,
                ]
            }
        }
        if let preMealTargetRange = preMealTargetRange {
            dict["pre_meal_lower_mgdl"] = preMealTargetRange.lowerBound.mgdl
            dict["pre_meal_upper_mgdl"] = preMealTargetRange.upperBound.mgdl
        }
        return dict
    }
}

extension TemporaryScheduleOverride {
    var homeAssistantRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "start_date": HomeAssistantDateFormatter.string(from: startDate),
        ]
        if duration.isFinite {
            dict["end_date"] = HomeAssistantDateFormatter.string(from: scheduledEndDate)
        }
        switch context {
        case .preMeal:
            dict["name"] = "Pre-Meal"
        case .legacyWorkout:
            dict["name"] = "Workout"
        case .preset(let preset):
            dict["name"] = preset.name
            dict["symbol"] = preset.symbol
        case .custom:
            dict["name"] = "Custom"
        }
        if let scaleFactor = settings.insulinNeedsScaleFactor {
            dict["insulin_needs_scale_factor"] = scaleFactor
        }
        if let targetRange = settings.targetRange {
            dict["target_range_lower_mgdl"] = targetRange.lowerBound.mgdl
            dict["target_range_upper_mgdl"] = targetRange.upperBound.mgdl
        }
        return dict
    }
}
