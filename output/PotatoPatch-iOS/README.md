# Potato Patch — native iOS game

Open `PotatoPatch.xcodeproj` in Xcode. Choose an iPhone simulator or your connected iPhone and press Run. Requires iOS 17 or newer. The native SwiftUI game is in `PotatoPatch.swift`.

Tap the potato to earn one potato. Buy Better trowel (15 potatoes initially) for +1 per tap, Potato farmer (30) for +1 per second, Harvest basket (125) for +5 per tap, and Rolling fields (350) for +10 per second. Six more upgrades extend the progression: Golden gloves (+25/tap, 1,200), Greenhouse (+50/second, 2,500), Super spade (+100/tap, 7,000), Spud factory (+250/second, 15,000), Potato wizard (+500/tap, 40,000), and Moon farm (+1,500/second, 100,000). Prices increase 18% per purchase, rounded up. Automatic harvesting works while the app is active. Progress saves locally; resetting requires confirmation.

The opaque 1024px icon in `Assets.xcassets/AppIcon.appiconset` is configured as the app's iPhone Home Screen icon. `Simulator/PotatoPatch.app` is the simulator build; `Device/PotatoPatch.app` is the signed device build. Device builds use a development profile and may need rebuilding when it expires.

Validation on October 3, 2026: simulator Debug and signed device Release builds passed. Simulator launch and visual inspection passed; see `preview.png`. Native model checks passed for tapping, prices, upgrades, insufficient funds, automatic production, background pause, saving/loading, and reset. Full touch gameplay has not been playtested.

Installation on the connected iPhone 16 Pro was blocked because it already has three apps installed with free developer profiles. Remove one of those apps (which may delete its saved progress), then run this project from Xcode to install Potato Patch and its icon. Existing apps were left in place.

The expanded version adds floating harvest counts, radial particles, potato bounce and rotation, and purchase haptics. Reduced Motion disables the tap animations. Existing four-upgrade saves migrate automatically, preserving balance and purchases. Upgrade and migration checks passed for both native and HTML versions.
