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

## Releasing (.dmg)

Requires [create-dmg](https://github.com/create-dmg/create-dmg) (`brew install create-dmg`) for a proper drag-to-Applications layout — the script falls back to a plain `hdiutil` image without it.

```sh
./Scripts/build-dmg.sh
```

This regenerates the Xcode project, builds a Release configuration, ad-hoc signs it (fixed in `project.yml` via `CODE_SIGN_IDENTITY: "-"`, so the result doesn't depend on whatever's in your keychain), and writes `build/Macby-<version>.dmg`. Bump `MARKETING_VERSION` in `project.yml` before releasing a new version — the script names the `.dmg` after it.

Ad-hoc signing means anyone who downloads it hits Gatekeeper's "Apple could not verify..." warning on first launch and has to right-click the app → Open once to get past it. That's the tradeoff for not paying for a Developer ID certificate.

To publish it on GitHub:

```sh
gh release create v0.1.0 build/Macby-0.1.0.dmg --title "Macby 0.1.0" --notes "..."
```

or upload the `.dmg` as a release asset via the GitHub web UI. The git tag is independent of `MARKETING_VERSION` — keep them in sync by convention, not enforcement.

## Cleaning

Remove all generated/build artifacts (generated Xcode project, SPM build products, DerivedData):

```sh
rm -rf Macby.xcodeproj build Packages/MacbyKit/.build
rm -rf ~/Library/Developer/Xcode/DerivedData/Macby-*
```

Reset Macby's own app state (clipboard history database, settings, first-run onboarding) — useful for testing a clean install:

```sh
rm -f ~/Library/Application\ Support/Macby/macby.sqlite
rm -rf ~/Library/Application\ Support/Macby/blobs
defaults delete com.macby.app 2>/dev/null
```

Also quit any running Macby instance first (`pkill -f Macby.app/Contents/MacOS/Macby`), and if you're testing permission prompts, revoke Accessibility/Screen Recording for Macby under System Settings → Privacy & Security — deleting app state doesn't reset those.

### Multiple "Macby" apps showing up in Spotlight/Launchpad

Every `.app` bundle on disk gets registered by Launch Services and shows up in Spotlight/Launchpad, not just the one in `/Applications` — a Debug build in DerivedData, `build/Release/Macby.app`, etc. all count as separate entries even though they're all "Macby." `Scripts/build-dmg.sh` cleans up its own scratch copy automatically, but if you end up with duplicates from manual testing, delete the extra `.app` copies (the `rm -rf` commands above) and Launch Services will drop them on its own, or force it immediately:

```sh
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Applications/Macby.app
```

`/Applications/Macby.app` is always the one to keep. Everything else under this repo or DerivedData is a build artifact.

