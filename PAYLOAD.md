# Loop → Home Assistant payload contract

The HomeAssistantService plugin POSTs JSON to the Home Assistant webhook URL
(`https://<ha>/api/webhook/<id>`). All dates are ISO 8601 with fractional
seconds, UTC. All glucose values are mg/dL (Home Assistant can convert for
display). Every key is optional — a payload contains only what changed.

```jsonc
{
  "timestamp": "2026-07-17T18:04:05.123Z",

  // From uploadGlucoseData - oldest first
  "glucose": [
    {
      "date": "2026-07-17T18:00:00.000Z",
      "value_mgdl": 112.0,
      "trend": "flat",                      // Loop GlucoseTrend name
      "trend_rate_mgdl_per_min": 0.2,
      "device": "CGM name",
      "is_calibration": false
    }
  ],

  // From uploadDoseData
  "doses": [
    {
      "type": "bolus",                      // bolus | basal | tempBasal | suspend | resume
      "start_date": "2026-07-17T17:55:00.000Z",
      "end_date": "2026-07-17T17:55:30.000Z",
      "delivered_units": 1.35,
      "programmed_units": 1.35,
      "rate_units_per_hour": null,
      "automatic": true
    }
  ],

  // From uploadCarbData
  "carbs": [
    {
      "date": "2026-07-17T17:30:00.000Z",
      "grams": 45.0,
      "absorption_time_minutes": 180,
      "food_type": "🌮"
    }
  ],

  // From uploadPumpEventData
  "pump_events": [
    { "date": "2026-07-17T17:00:00.000Z", "type": "rewind", "description": "..." }
  ],

  // Derived from the most recent StoredDosingDecision
  "dosing_decision": {
    "date": "2026-07-17T18:00:10.000Z",
    "insulin_on_board": 2.41,
    "carbs_on_board": 18.0,
    "eventual_glucose_mgdl": 124.0,       // last predicted glucose value
    "recommended_bolus": 0.0
  },

  // Snapshot state, sent alongside dosing decisions
  "status": {
    "closed_loop": true,
    "last_loop_completed": "2026-07-17T18:00:10.000Z",
    "basal_rate": 0.85,                   // current effective U/h if known
    "reservoir_units": 112.0,
    "pump_battery_percent": 75,
    "pump_suspended": false
  },

  // Active override, or null when none is active (key present = authoritative)
  "override": {
    "name": "Exercise",
    "symbol": "🏃",
    "start_date": "2026-07-17T17:00:00.000Z",
    "end_date": "2026-07-17T19:00:00.000Z",
    "insulin_needs_scale_factor": 0.7,
    "target_range_lower_mgdl": 140.0,
    "target_range_upper_mgdl": 160.0
  }
}
```

The Home Assistant integration keeps the latest value per category and fires a
`loop_data_received` event on every push (with `pump_events` included) for use
in automations.
