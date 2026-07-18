#!/bin/sh -e
#
# Adds the Loop Home Assistant Service plugin to a LoopWorkspace checkout.
#
# Run from the root of your LoopWorkspace:
#   curl -fsSL https://raw.githubusercontent.com/Camji55/loop-homeassistant-service/main/Scripts/install.sh | sh
#
# Safe to re-run; each step is skipped if already done.

REPO_URL="https://github.com/Camji55/loop-homeassistant-service.git"
WORKSPACE_DATA="LoopWorkspace.xcworkspace/contents.xcworkspacedata"
SCHEME="LoopWorkspace.xcworkspace/xcshareddata/xcschemes/LoopWorkspace.xcscheme"

if [ ! -f "$WORKSPACE_DATA" ]; then
    echo "error: run this from the root of your LoopWorkspace checkout" >&2
    exit 1
fi

if [ ! -f "HomeAssistantService/HomeAssistantService.xcodeproj/project.pbxproj" ]; then
    echo "==> Adding HomeAssistantService submodule"
    git submodule add "$REPO_URL" HomeAssistantService
else
    echo "==> Submodule already present, skipping"
fi

python3 - "$WORKSPACE_DATA" "$SCHEME" <<'PYEOF'
import sys

workspace_path, scheme_path = sys.argv[1], sys.argv[2]

# --- Register the project in the workspace ---
with open(workspace_path) as f:
    workspace = f.read()

if "HomeAssistantService/HomeAssistantService.xcodeproj" in workspace:
    print("==> Workspace already references the project, skipping")
else:
    ref = ('   <FileRef\n'
           '      location = "group:HomeAssistantService/HomeAssistantService.xcodeproj">\n'
           '   </FileRef>\n')
    workspace = workspace.replace("</Workspace>", ref + "</Workspace>")
    with open(workspace_path, "w") as f:
        f.write(workspace)
    print("==> Added project to workspace")

# --- Add the plugin to the shared build scheme, before Loop.app ---
with open(scheme_path) as f:
    scheme = f.read()

if "HomeAssistantServiceKitPlugin" in scheme:
    print("==> Scheme already builds the plugin, skipping")
else:
    anchor = scheme.find('BuildableName = "Loop.app"')
    if anchor == -1:
        sys.exit("error: could not find Loop.app entry in LoopWorkspace.xcscheme")
    insert_at = scheme.rfind("<BuildActionEntry", 0, anchor)
    if insert_at == -1:
        sys.exit("error: malformed LoopWorkspace.xcscheme")
    entry = ('<BuildActionEntry\n'
             '            buildForTesting = "YES"\n'
             '            buildForRunning = "YES"\n'
             '            buildForProfiling = "YES"\n'
             '            buildForArchiving = "YES"\n'
             '            buildForAnalyzing = "YES">\n'
             '            <BuildableReference\n'
             '               BuildableIdentifier = "primary"\n'
             '               BlueprintIdentifier = "AA000000000000000000T003"\n'
             '               BuildableName = "HomeAssistantServiceKitPlugin.loopplugin"\n'
             '               BlueprintName = "HomeAssistantServiceKitPlugin"\n'
             '               ReferencedContainer = "container:HomeAssistantService/HomeAssistantService.xcodeproj">\n'
             '            </BuildableReference>\n'
             '         </BuildActionEntry>\n'
             '         ')
    scheme = scheme[:insert_at] + entry + scheme[insert_at:]
    with open(scheme_path, "w") as f:
        f.write(scheme)
    print("==> Added plugin to the Loop (Workspace) build scheme")
PYEOF

echo ""
echo "Done. Build the 'Loop (Workspace)' scheme as usual."
echo "Building with GitHub Actions? Commit and push these changes to your fork:"
echo "  git add .gitmodules HomeAssistantService $WORKSPACE_DATA $SCHEME"
