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

Every `.app` bundle on disk gets registered by Launch Services and shows up in Spotlight/Launchpad, not just the copy you actually run — a Debug build in DerivedData, an old copy in `/Applications`, etc. all count as separate entries even though they're all "Macby." Delete whichever copies you're not using (the `rm -rf` commands above) and Launch Services will drop them on its own, or force it immediately:

```sh
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Applications/Macby.app
```

Rebuilding changes the code signature every time (debug builds are ad-hoc signed), which invalidates any previously granted Accessibility permission — after rebuilding, re-grant it under System Settings → Privacy & Security → Accessibility rather than assuming a stale grant still applies.

