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
