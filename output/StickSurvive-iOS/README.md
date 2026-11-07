# Stick & Survive — native iOS

Open `StickSurvive.xcodeproj` in Xcode. Select the **StickSurvive** scheme and an iPhone or iPad Simulator, then press Run. The current project builds for iOS 17 or later. The game runs in landscape. Simulator builds do not require a development team; signing is disabled specifically for the Simulator SDK. Choose an actual Simulator destination rather than “Any iOS Device” to run without a team.

For a physical device, select your development team in Signing & Capabilities, use a unique bundle identifier if needed, choose your connected device, and press Run. The included device build is unsigned; Xcode must sign it before installation.

## Controls

- Left circular pad: drag to move; release to stop.
- Right circular pad: drag to aim and hold to fire; release to stop firing.
- Connected keyboard: W/A/S/D to move; Space to fire toward your last aim direction.
- Pause: top-right button. The game automatically pauses when backgrounded.
- Between runs: Change weapon cycles your unlocked arsenal; Level cycles unlocked levels.

## Game

Clear ten waves to win and unlock the next level. Enemy health, speed, damage, and count increase. Arena layouts and colors vary by level. Hearts restore 25 health. Collect coins to buy field crates (40) or elite crates (100) from the shop before or after a run. Duplicate weapons refund half the box price. Wins award a coin bonus. Coins and unlocked weapons save on the device with UserDefaults.

The full game is in `StickSurvive.swift`, using SceneKit for a lit 3D arena, UIKit for the HUD, and native multi-touch input. No web view, third-party libraries, network access, or downloaded assets.

The app uses the UIKit scene lifecycle required by the iOS 27 SDK. Xcode generates the scene manifest for Debug and Release; `AppDelegate` supplies the scene configuration, and `SceneDelegate` creates the game window attached to its `UIWindowScene`.

`Simulator/StickSurvive.app` is the built Simulator app. `Device-Unsigned/StickSurvive.app` is the unsigned iOS device build. Neither is a macOS app.

Build from the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project noah/output/StickSurvive-iOS/StickSurvive.xcodeproj \
  -scheme StickSurvive -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/stick-ios-derived CODE_SIGNING_ALLOWED=NO build
```

Validation (October 3, 2026): the iPhone Simulator Debug and unsigned iOS device Release builds passed. The app launched on iPhone 18 Pro Simulator; pistol, shotgun, rifle projectile generation and pistol collision damage assertions passed. The 3D arena was visually inspected; `arena-preview.png` is the captured screen. Full touch gameplay has not been playtested.

Physical installation on the connected Noah J iPhone 16 Pro is pending: the existing provisioning profile does not include that device. Registering the device and updating the Apple developer profile requires explicit approval. Once approved, build with automatic provisioning enabled and install the signed app; the included AppIcon will appear on the Home Screen.

## App icon

`Assets.xcassets/AppIcon.appiconset/AppIcon.png` contains the opaque 1024 × 1024 icon. Both build configurations select this icon; Xcode compiles the iPhone and iPad Home Screen sizes automatically. Rebuild and install from Xcode to show the icon on your iPhone.

New players start with the Pistol. The arena uses 3D stickmen, projectiles, coins, hearts, raised obstacles, lighting, and shadows. Loot boxes use only coins earned in gameplay.
