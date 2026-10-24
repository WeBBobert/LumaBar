# LumaBar 0.2.0

Original rootless Theos tweak: Home Bar customization, gestures, system
actions, a Settings pane, and Sileo-installable packaging.
Package ID: `com.lumabar.tweak`.

## Build
macOS needs GNU make 4+ (`brew install make`, then use `gmake`).

    gmake package FINALPACKAGE=1

The `.deb` lands in `packages/`. Install via Sileo/Filza or `dpkg -i`, then
respring.

## iOS 18 notes (written without access to an iOS 18 device)
Private class and selector names change between iOS releases, so this
version is built to discover its environment instead of assuming it:
- The pill view is located by several KVC keys, then by class-name search.
- Custom color draws our own bar over the system pill.
- Gestures are caught by a transparent view beside the grabber, not on it.
- Every action has an ordered list of candidate selectors, guarded so a
  miss does nothing instead of crashing.
- A diagnostic report is written automatically ~8s after the first grabber
  appears, and on demand from Settings > LumaBar > Write Debug Report, to
  `/var/mobile/Documents/LumaBar-debug.txt`.

## First run
1. Install, respring, wait 10 seconds.
2. Try each gesture on the home bar a few times.
3. Settings > LumaBar > Write Debug Report, then read the file in Filza.
The report shows the real view hierarchy, which selectors exist, and whether
the gesture catcher received touches. Use it to correct the candidate tables.

## Known gaps
- Screen Recording is not implemented.
- Spotlight candidates are guesses.
- Swipe up overlaps the system home gesture.
- arm64e: iPhone 11 is arm64e. If SpringBoard crash-loops on load, suspect the
  arm64e ABI of the build toolchain and enter safe mode to remove the package.

## Your own repo (later)
Put the `.deb` in a folder, run `dpkg-scanpackages -m . > Packages`, compress
with `bzip2`/`xz`, add a `Release` file, and host the folder. Add the URL in
Sileo.
