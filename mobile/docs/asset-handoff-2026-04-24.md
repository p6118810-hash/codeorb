# CodeOrb App Asset Handoff - 2026-04-24

This note summarizes what app-side source assets currently exist in `mobile/`, what is still missing, and which product/demo shots best represent the current build.

## 1. Existing source assets

### Logo / icon assets
- Primary app icon set:
  - `CodeOrb/Assets.xcassets/AppIcon.appiconset/icon_16x16.png`
  - `CodeOrb/Assets.xcassets/AppIcon.appiconset/icon_32x32.png`
  - `CodeOrb/Assets.xcassets/AppIcon.appiconset/icon_64x64.png`
  - `CodeOrb/Assets.xcassets/AppIcon.appiconset/icon_128x128.png`
  - `CodeOrb/Assets.xcassets/AppIcon.appiconset/icon_256x256.png`
  - `CodeOrb/Assets.xcassets/AppIcon.appiconset/icon_512x512.png`
  - `CodeOrb/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png`
- README currently uses `CodeOrb/Assets.xcassets/AppIcon.appiconset/icon_128x128.png`

### App/product references
- Product summary / feature list:
  - `README.md`
- Main notch/orb UI implementation:
  - `CodeOrb/UI/Views/NotchView.swift`
  - `CodeOrb/UI/Views/NotchHeaderView.swift`
- Processing / status indicator behavior:
  - `CodeOrb/UI/Components/ProcessingSpinner.swift`
  - `CodeOrb/UI/Views/ChatView.swift`
  - `CodeOrb/UI/Views/CodexInstancesView.swift`

## 2. Missing assets in repo right now

The repo does **not** currently contain reusable marketing exports for:
- Clean screenshots of latest UI states
- Screen recordings / GIFs
- Transparent-background logo exports separate from the app icon set
- A dedicated design spec file for the orb / notch system

So if marketing/demo materials are needed immediately, they will need to be captured from the running macOS app rather than pulled from committed assets.

## 3. Current orb / notch visual notes

### Compact orb / mascot
- The compact orb is a circular dark surface with a glow halo and a status badge.
- The left mascot has recently changed to a **solar-system motif** rather than the old crab concept.
- The mascot uses:
  - circular orbits centered on the sun
  - provider-colored planets for active running sessions
  - no orbit rings when there are no active planets
  - a fly-in effect when planets enter orbit
- Provider planet colors are currently mapped as:
  - Codex: lime green
  - Claude: orange
  - Gemini: blue

### Status behavior
Compact orb states exposed by the current UI:
- `idle`
- `processing`
- `waitingForApproval`
- `waitingForInput`

Key status labels/badges in current build:
- processing: `RUN`
- waiting for approval: `ASK`
- waiting for input: `READY`

### Styling notes in current build
- Running-state accents that used to be orange have been changed to black in several places.
- Orb tracks multiple running providers and shows them as planets on separate orbits.
- The center sun and orbit line weight have both been tuned down in the latest local build for a lighter look.

## 4. Best demo / product shot list

Recommended capture order for the current app:
1. **Idle compact orb**
   - No active planets / no orbit rings.
   - Good for baseline branding shot.
2. **Single running session**
   - One provider planet orbiting the sun.
   - Shows the compact orb in live monitoring mode.
3. **Two to three running sessions**
   - Shows the solar-system metaphor clearly with multiple providers.
   - Best shot for communicating multi-session support.
4. **Permission / approval state**
   - Closed notch with left mascot and right approval indicator.
   - Good for the “approve tool” product story.
5. **Waiting-for-input / ready state**
   - Shows the notch bounce / ready emphasis and the READY status.
   - Good for “agent needs you” messaging.
6. **Expanded notch header + content**
   - Open notch with header and main content visible.
   - Use for general product hero shots.
7. **Chat view with tool activity**
   - Shows prompts, tools, and completion flow.
   - Good for “watch turns live without living in terminal”.
8. **Instances / multi-agent overview**
   - Use `CodexInstancesView` to show multiple sessions in one place.
   - Best shot for the “multi-agent overview” request.
9. **Jump-to-terminal / focus flow**
   - Capture from a state where the app focuses the related terminal session.
   - Good for “monitor -> jump” workflow.
10. **Menu / settings panel**
   - Useful as a supporting product shot if website/demo needs configuration context.

## 5. Notable newer / likely not-yet-website-reflected changes

These are the most likely items newer than older site captures:
- Solar-system mascot replacing the previous left-side icon concept
- Provider-colored planets for concurrent running sessions
- More polished compact orb treatment for run / ask / ready states
- Multi-session compact summary strip next to the orb
- Refined thin-orbit visual and smaller sun in latest local build
- Black approval / running accents replacing previous orange emphasis

## 6. Suggested next capture pass

If a capture pass is scheduled, prioritize this exact set:
- 3 clean PNG screenshots:
  - idle compact orb
  - 2-planet running orb
  - waiting-for-approval closed notch
- 3 short recordings / GIFs:
  - planet fly-in to orbit when a run starts
  - approval -> running transition
  - waiting-for-input / ready transition
- 1 wider overview capture:
  - open notch with instances list or chat + activity visible

