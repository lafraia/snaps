<p align="center">
  <img src="assets/banner.jpg" alt="Snaps: screenshots that land on your clipboard" width="100%">
</p>

<p align="center">
  <a href="https://nearbycoder.github.io/snaps/"><b>Website</b></a> ·
  <a href="https://github.com/nearbycoder/snaps/releases/latest"><b>Download</b></a> ·
  <a href="https://nearbycoder.github.io/snaps/#top"><b>Watch the demo</b></a>
</p>

# Snaps

A tiny native macOS menu bar app for screenshots, with a Liquid Glass look. **Free and open source (MIT).**

Every capture goes straight to your clipboard and appears as a floating preview in the corner of your choice, so you can paste it with ⌘V or drag it into any app.

## Install

1. Download the latest **Snaps-x.y.z.dmg** from [Releases](https://github.com/nearbycoder/snaps/releases/latest).
2. Open it and drag **Snaps** into **Applications**.
3. Launch Snaps and allow **Screen Recording** when asked (System Settings → Privacy & Security → Screen & System Audio Recording), then relaunch it.

Requires macOS 26 or later. Releases are signed with a Developer ID and notarized by Apple.

<p align="center">
  <a href="https://nearbycoder.github.io/snaps/"><img src="docs/assets/promo-poster.jpg" alt="Watch the Snaps promo video" width="720"></a>
</p>

## Shortcuts

| Capture | Default | What it does |
| --- | --- | --- |
| Area | ⌃⇧4 | Drag to select a region |
| Window | ⌃⇧5 | Click a window to capture it |
| Full Screen | ⌃⇧3 | Captures the display under your cursor |
| Gallery | ⌃⇧G | Shows recent captures in a strip across the top of the screen |

Change them in **Settings → Shortcuts**: click a shortcut and type a new combo. Esc cancels, Delete clears it.

## The preview

- Appears in the bottom-left corner by default. Change the corner from the menu bar popover or in Settings.
- Follows your cursor between displays: move to another monitor and the previews hop to that display's corner. They stay put while a mouse button is held, so you can drag one across.
- **Drag** it into Finder, Slack, Mail, a browser, and so on. It dismisses itself after a successful drop.
- **Hover** to reveal buttons for close, pin (keeps it on screen), copy again, save / show in Finder, and open.
- **Double-click** to open the image in Preview.
- Auto-dismisses after 5, 10 or 20 seconds, or stays until you close it.

## The gallery

Press ⌃⇧G, or click **Gallery** in the menu bar popover. A glass strip drops down across the top of the screen, over the menu bar, with your recent captures (newest first).

- **Click** a capture to copy it. **Drag** it into any app. **Double-click** to open it.
- **Hover** for remove, copy and save / show in Finder.
- Press **Esc**, click outside, or press the shortcut again to close it.
- Like the previews, it moves to whichever display your cursor is on.

The gallery keeps your last 60 captures. Unsaved captures are cleaned up after 7 days; anything saved to a folder stays in the gallery as long as the file exists.

## Build from source

Requires macOS 26 or later.

```sh
./Scripts/build.sh          # builds build/Snaps.app
./Scripts/build.sh run      # builds and launches
./Scripts/build.sh install  # builds, copies to /Applications, launches
```

The script compiles with `swiftc` directly. It works with just the Command Line Tools, or with Xcode once its license has been accepted.

### Screen Recording permission

On first launch macOS asks for **Screen Recording** access. Grant it in System Settings → Privacy & Security → Screen & System Audio Recording, then relaunch Snaps. Without it, captures only contain your wallpaper.

Local builds are signed with your Apple Development certificate if you have one, otherwise ad-hoc; set `SIGN_IDENTITY` to override. With ad-hoc signing, macOS may ask for the permission again after each rebuild.

## Releasing

```sh
./Scripts/release.sh           # archive, sign with Developer ID, notarize, package
./Scripts/release.sh publish   # ...and publish a GitHub release for the version
```

The release script generates an Xcode project from `project.yml` (needs `brew install xcodegen`). It archives the app, then exports it with Developer ID signing and has Xcode submit it to Apple's notary service, using the account you're signed into in Xcode. Once notarization passes, it staples the ticket, verifies the app with Gatekeeper, and packages `Snaps-<version>.dmg`, `Snaps-<version>.zip` and `SHA256SUMS.txt` into `build/release`.

Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist` before each release.

## Project layout

```
Sources/Snaps/
  SnapsMain.swift        app entry point (menu bar / accessory app)
  AppCoordinator.swift   wires hotkeys → capture → clipboard → preview
  AppSettings.swift      persisted preferences + runtime state
  Capture.swift          screencapture wrapper, file storage, clipboard
  HotKeyCenter.swift     global shortcuts via Carbon hot keys
  Shortcut.swift         shortcut model + key names
  Preview.swift          floating glass preview panels + stacking
  Gallery.swift          top-of-screen gallery strip
  ScreenFollower.swift   moves floating UI to the cursor's display
  CaptureHistory.swift   recent captures store + thumbnail cache
  PreviewCardView.swift  preview UI and drag-out source
  StatusBar.swift        menu bar item + glass popover
  SettingsView.swift     settings window + shortcut recorder
Scripts/
  build.sh               local build/sign/install script (renders the app icon from assets/icon.svg)
  release.sh             Developer ID + notarized release builds
  make-banner.swift      renders assets/banner.jpg
project.yml              XcodeGen project definition (used for releases)
docs/                    GitHub Pages site (index.html, promo video, assets)
promo/                   promo video source (promo.html) + renderer (render.mjs)
assets/
  icon.svg               logo / app icon source
  banner.jpg             README + social preview banner
```

## Website and promo video

The site in `docs/` is served by GitHub Pages at https://nearbycoder.github.io/snaps/.

The promo video is an HTML/CSS animation (`promo/promo.html`) rendered frame by frame with headless Chrome and ffmpeg:

```sh
cd promo && npm install
npm run stills   # PNG stills of key moments → promo/stills
npm run render   # docs/assets/promo.mp4 + promo-poster.jpg (1080p60)
```

Open `promo/promo.html` in a browser to watch it play live.

## License

[MIT](LICENSE). Snaps is free to use, modify and share.
