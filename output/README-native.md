# Stick & Survive — native macOS game

Double-click **StickSurvive.app** in Finder to play. Requires macOS 13 or later. Built for this Mac's processor.

- WASD: move. Mouse or arrow keys: aim. Hold click or Space: attack.
- P or Escape: pause. Losing window focus automatically pauses.
- Clear ten waves to win and unlock the next, harder level. Four arena layouts and color themes rotate; enemy health, speed, count, and damage increase with level.
- Coins save as soon as collected. Hearts restore 25 health.
- Visit the shop from the menu or after a run. Field crates cost 40 coins; elite crates cost 100. Duplicate weapons refund half the cost. Weapons persist for future runs.
- Use Change weapon and the Level button between runs to cycle unlocked choices.
- Progress is stored in macOS UserDefaults under local.noah.sticksurvive.

The game is implemented in the single source file **StickSurvive.swift**, using AppKit and native drawing, with no browser or third-party dependencies.

Rebuild from the project root:

```sh
xcrun swiftc noah/output/StickSurvive.swift -o noah/output/StickSurvive.app/Contents/MacOS/StickSurvive -framework Cocoa -module-cache-path /private/tmp/stick-survive-swift-cache
codesign --force --sign - noah/output/StickSurvive.app
```
