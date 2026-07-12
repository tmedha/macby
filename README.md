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

