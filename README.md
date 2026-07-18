# Loop Home Assistant Service

A service plugin for [Loop](https://github.com/LoopKit/Loop), the DIY
closed-loop insulin delivery app, that pushes your diabetes data to
[Home Assistant](https://www.home-assistant.io) in real time — glucose,
insulin on board, carbs, pump status, therapy settings, overrides, and
alerts — over a local webhook. No cloud account, no polling.

Works together with the
[loop-homeassistant](https://github.com/Camji55/loop-homeassistant) custom
integration (installable via HACS), which turns the pushed data into Home
Assistant entities and events. The wire format is documented in
[PAYLOAD.md](PAYLOAD.md).

> **Note:** This plugin is not part of the standard LoopWorkspace. You add it
> to your own Loop build — see below. It only *sends* data; it cannot bolus or
> change any Loop settings from Home Assistant.

## What it does

Loop hands every new batch of data to the plugin via LoopKit's
`RemoteDataService` protocol; the plugin converts it to JSON and POSTs it to a
Home Assistant webhook URL you paste in once. Uploads that fail (phone away
from home without an external URL, HA restarting) are retried automatically by
Loop's sync anchors, so history backfills on its own.

## Adding this plugin to Loop

From the root of your
[LoopWorkspace](https://github.com/LoopKit/LoopWorkspace) checkout, run:

```bash
curl -fsSL https://raw.githubusercontent.com/Camji55/loop-homeassistant-service/main/Scripts/install.sh | sh
```

That adds the submodule, registers the project in the workspace, and adds the
plugin to the **Loop (Workspace)** build scheme. It's safe to re-run — each
step is skipped if already done. Then build Loop as usual.

**Building with GitHub Actions ("browser build")?** Run the script once on any
machine with the repo cloned (or make the same edits via github.dev), then
commit and push the changes to your fork — the Actions build picks them up
automatically.

<details>
<summary><b>Manual steps</b> (what the script does)</summary>

### 1. Add the submodule

```bash
cd LoopWorkspace
git submodule add https://github.com/Camji55/loop-homeassistant-service.git HomeAssistantService
```

> The folder name **must** be `HomeAssistantService` — the project references
> assume it.

### 2. Add the project to the workspace

Either open `LoopWorkspace.xcworkspace` in Xcode and drag
`HomeAssistantService/HomeAssistantService.xcodeproj` into the project
navigator (at the top level, next to NightscoutService), **or** add this line
to `LoopWorkspace.xcworkspace/contents.xcworkspacedata` alongside the other
`FileRef` entries:

```xml
<FileRef
   location = "group:HomeAssistantService/HomeAssistantService.xcodeproj">
</FileRef>
```

### 3. Add the plugin to the build scheme

In Xcode: **Product → Scheme → Edit Scheme… → Loop (Workspace) → Build →
"+"** and add **HomeAssistantServiceKitPlugin**, positioned anywhere above
`Loop.app`.

Or edit `LoopWorkspace.xcworkspace/xcshareddata/xcschemes/LoopWorkspace.xcscheme`
and add this `BuildActionEntry` next to the other service plugins:

```xml
<BuildActionEntry
   buildForTesting = "YES"
   buildForRunning = "YES"
   buildForProfiling = "YES"
   buildForArchiving = "YES"
   buildForAnalyzing = "YES">
   <BuildableReference
      BuildableIdentifier = "primary"
      BlueprintIdentifier = "AA000000000000000000T003"
      BuildableName = "HomeAssistantServiceKitPlugin.loopplugin"
      BlueprintName = "HomeAssistantServiceKitPlugin"
      ReferencedContainer = "container:HomeAssistantService/HomeAssistantService.xcodeproj">
   </BuildableReference>
</BuildActionEntry>
```

### 4. Build Loop

Build the **Loop (Workspace)** scheme as usual. Loop's existing
`copy-plugins.sh` build phase finds the built `.loopplugin` and embeds it —
no changes to Loop itself are needed.

</details>

## Setup

1. In Home Assistant, install the
   [loop-homeassistant](https://github.com/Camji55/loop-homeassistant)
   integration and add it (**Settings → Devices & Services → Add Integration
   → Loop**). Copy the webhook URL it shows you — use your external HTTPS URL
   (Nabu Casa / reverse proxy) if your phone leaves home Wi-Fi.
2. In Loop: **Settings → Services → Add Service → Home Assistant**, paste the
   URL, tap **Test Connection**, then **Save**.

## Security

The unguessable webhook ID is the only secret; it is stored in the iOS
Keychain. The webhook can only receive data — nothing can be read back or
commanded through it. Use HTTPS for any URL reachable from the internet.

## Disclaimer

This is not a medical device. Do not rely on Home Assistant for
hypo/hyperglycemia alerting.
