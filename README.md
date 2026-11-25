# 云转 PanRelay

SwiftUI iOS 15 UI prototype for batch netdisk relay and copy rewriting. This first phase uses mock data only; network services are represented by protocols and mock implementations.

## Structure

- App/ app entry point and shared observable state
- Views/ Transfer, Rewrite, Netdisk, Models, and History screens
- Components/ theme, grid background, controls, cards, tab bar, and share sheet
- Services/Netdisk/ NetdiskAdapter protocol and mock adapter
- Services/AI/ streaming AI protocol and mock stream implementation
- Models/ UI and domain models
- Storage/ mock persistence protocol
- Resources/Fonts/ Space Grotesk and JetBrains Mono variable fonts
- .github/workflows/build-ipa.yml unsigned IPA build

## Local project generation

~~~bash
brew install xcodegen
xcodegen generate
open PanRelay.xcodeproj
~~~

The project targets iOS 15 and uses Swift 5.9. The app is configured without code signing for the CI archive step.

## GitHub Actions IPA

Push to main or run Build unsigned IPA from the Actions tab. Download the PanRelay-unsigned-ipa artifact.

## TrollStore install

Transfer PanRelay-unsigned.ipa to the iPhone, open it from Files or TrollStore, and choose Install. The workflow intentionally leaves the app unsigned for TrollStore installation.
