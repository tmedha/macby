# macby
The only clipboard you need for your MacBook.

You can use the Makefile to build a .dmg for yourself, or you can go to [macby-download](tmedha.com/macby-download) and download
the installer for MacOS from there.

## Requirements

- Xcode (15 or later)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Build & install

```sh
git clone https://github.com/tmedha/macby.git
cd macby
make build
```

This produces `Macby.app` under `build/Release/`. Move it into `/Applications`:

```sh
cp -R build/Release/Macby.app /Applications/
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
