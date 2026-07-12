# macby
The only clipboard you need for your MacBook.

## Building

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the Xcode project is generated from `project.yml` and is not checked in.

```sh
xcodegen generate
open Macby.xcodeproj
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project Macby.xcodeproj -scheme Macby -configuration Debug build
```

Core logic lives in the local Swift package at `Packages/MacbyKit` and can be built/tested independently:

```sh
cd Packages/MacbyKit
swift test
```

### Development signing note

Debug builds are ad-hoc signed ("Sign to Run Locally"), which means **every rebuild changes the code signature**, so macOS treats each rebuild as a new app for TCC purposes — you'll be asked to re-grant Accessibility (and, on first snip capture, Screen Recording) after every rebuild during development. This goes away once distributing with a stable identity (below).

## Distributing outside the Mac App Store

Macby is unsandboxed by design (see the architecture notes) — it needs Accessibility, Screen Recording, and paste-simulation capabilities that Mac App Store sandboxing doesn't allow. Distributing a build to anyone besides yourself requires your own Apple Developer Program membership and these one-time/per-release steps, none of which this repo can do for you:

1. **Get a Developer ID Application certificate** from your Apple Developer account (Certificates, Identifiers & Profiles), installed in your local Keychain.
2. **Sign with that identity** instead of ad-hoc signing — in `project.yml`, set `CODE_SIGN_STYLE: Manual` and `CODE_SIGN_IDENTITY`/`DEVELOPMENT_TEAM` to your Team ID, or override via `xcodebuild ... CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" DEVELOPMENT_TEAM=TEAMID`.
3. **Archive and export** a signed `.app`:
   ```sh
   xcodebuild -project Macby.xcodeproj -scheme Macby -configuration Release archive -archivePath build/Macby.xcarchive
   xcodebuild -exportArchive -archivePath build/Macby.xcarchive -exportPath build/export -exportOptionsPlist ExportOptions.plist
   ```
   (`ExportOptions.plist` with `method: developer-id` is not included — create one per [Apple's docs](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).)
4. **Notarize** it with `notarytool` (requires an app-specific password or API key for your Apple ID):
   ```sh
   xcrun notarytool submit build/export/Macby.app.zip --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD --wait
   xcrun stapler staple build/export/Macby.app
   ```

None of this is needed for local development or testing — only for handing a build to someone else.
