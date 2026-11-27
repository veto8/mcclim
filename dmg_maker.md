# DMG Maker

How the macOS DMG gets its graphical install layout (background image + app icon + Applications symlink).

## What it does

`ask.d/dmg.sh` (task 4) stages the `.app` and an `Applications` symlink into a temp folder, then uses AppleScript to tell Finder to:

1. Open the staged folder as a disk image.
2. Switch to icon view, hide toolbar and statusbar.
3. Set a fixed window size.
4. Use `mcclim.svg` (converted to PNG via `sips`) as the background.
5. Position the `.app` on the left and `Applications` on the right.
6. Save the layout into `.DS_Store`.

After that, `hdiutil create` makes the compressed `UDZO` DMG from the staged folder. The result opens in Finder showing the app next to the Applications folder with the background image — the standard drag-to-install presentation.

## Requirements

- macOS (the script exits on non-Darwin).
- `osascript`, `hdiutil`, `sips`, `ditto`, `plutil` (all system tools).
- An SVG or PNG at the project root (`mcclim.svg`).

## How to run

```sh
./ask.sh
# select 4
```

Or directly:

```sh
sh ask.d/dmg.sh
```

Output lands in `dist/mcclim/mcclim_macos.dmg` (Apple silicon) or `dist/mcclim/mcclim_macos_intel.dmg` (Intel).