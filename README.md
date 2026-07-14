# macby
The only clipboard you need for your MacBook.

There's no downloadable build — you build it yourself and run the result. This is intentional: Macby needs Accessibility (and, for snip capture, Screen Recording) permission to work, and macOS ties those grants to the exact code signature of the binary. A pre-built release you download and periodically update would mean re-granting permissions after every update; building it yourself once means you only deal with that once.

## Requirements

- Xcode (15 or later)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Build & install

```sh
git clone https://github.com/tmedha/macby.git
cd macby
xcodegen generate
xcodebuild -project Macby.xcodeproj -scheme Macby -configuration Release build
```

This produces `Macby.app` under `~/Library/Developer/Xcode/DerivedData/Macby-*/Build/Products/Release/`. Move it into `/Applications`:

```sh
cp -R "$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -iname 'Macby-*' -print -quit)/Build/Products/Release/Macby.app" /Applications/
```

Then launch it. Either `open /Applications/Macby.app` or double-click it in Finder. It runs as a menu bar app (look for the clipboard icon), with no Dock icon or window.

(Prefer working in Xcode instead? `xcodegen generate` then `open Macby.xcodeproj`, pick the Macby scheme, and Cmd+R.)

## First launch

1. Click the menu bar icon to open the popover the first time you launch the app.
2. The popover will show a banner asking for Accessibility access, needed for keyboard shortcuts and pasting. Click **Fix…**, or grant it yourself under System Settings → Privacy & Security → Accessibility, then reopen the popover.
3. If you use the snip-capture shortcut (screen region → clipboard), macOS will separately prompt for Screen Recording access the first time you trigger it.
4. Open Macby's Settings (right-click the menu bar icon) to set your preferred shortcuts, enable Launch at Login, and configure a save folder for snips.

## Updating

Pull the latest changes and rebuild with the same commands above. Rebuilding changes the code signature, so macOS will ask you to re-grant Accessibility (and Screen Recording, if applicable) again — that's expected, not a bug.

## Uninstalling

```sh
pkill -f Macby.app/Contents/MacOS/Macby
rm -rf /Applications/Macby.app
rm -rf ~/Library/Application\ Support/Macby
defaults delete com.macby.app 2>/dev/null
```

Also remove Macby from System Settings → Privacy & Security → Accessibility / Screen Recording, since uninstalling the app doesn't revoke those on its own.

### Multiple "Macby" apps showing up in Spotlight/Launchpad

Every `.app` bundle on disk gets registered by Launch Services and shows up in Spotlight/Launchpad, not just the copy in `/Applications` — a build still sitting in DerivedData counts as a separate entry even though it's also "Macby." Delete whichever copies you're not using and Launch Services will drop them on its own, or force it immediately:

```sh
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Applications/Macby.app
```
