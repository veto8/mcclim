<img src="mcclim.svg" alt="McCLIM GUI logo" width="120">

# mcclim

Minimal Common Lisp GUI hello-world program built with McCLIM.

The window shows "Hello, world!" with a **Quit** button.

## Run

```sh
sbcl --script main.lisp
```

## No-window mode

```sh
./dist/mcclim/mcclim -- -nw
```

The `--` stops SBCL from parsing the flag as its own option. `-nw`, `--nw`, and `--no-window` skip the GUI and print `Hello, world!` to the terminal.
Without a flag, the executable opens the McCLIM window.

## Windows: native window without X11

The Windows build uses McCLIM 1.0.0's SDL2 backend, so it opens a native window and does not need an X server or `DISPLAY`.

1. Download `mcclim_windows.exe` from the release. It is a single-file launcher containing the SBCL image and `SDL2.dll`.
2. Run it. On first run it extracts them to `%LOCALAPPDATA%\McCLIM\Windows\<hash>` and starts the program. You do not need to download the DLL separately.
3. `-nw` works from PowerShell or Cmd.

If you prefer files you can inspect, download `mcclim_windows.zip`. It contains the raw `mcclim_windows_raw.exe` and `SDL2.dll`; keep them in the same folder. Running the raw executable without the DLL fails during SBCL startup with `Error opening shared object "SDL2.dll"`.

Keep `SDL2.dll` next to the raw executable (or on `PATH`) when using the zip; Windows uses SDL 2.32.8 x64. The `-nw` flag still works without SDL2. The Windows build first tries Chocolatey for SBCL, then falls back to the official SBCL MSI if the Chocolatey feed is unavailable. The raw image is saved with `:compression nil` because the Windows SBCL has no zstd support; other platforms use `:compression t`. The saved core cannot retain cl-sdl2's foreign user-event counter, so `main()` allocates a fresh one at startup before opening a port; the reset code lives in `sdl2-runtime.lisp` and is loaded only for SDL2 builds. The raw image is saved with `:application-type :gui` and the launcher is a GUI-subsystem executable, so neither creates a console window for GUI runs. `-nw` attaches to the parent console and writes `Hello, world!` directly, so it works without a GUI subsystem console. SDL2 windows are forced to be bordered and centered with `SDL_WINDOWPOS_CENTERED` before they are shown, so the title bar stays on screen in small or virtual displays.

## macOS DMG

Releases include `mcclim_macos.dmg` for Apple silicon and `mcclim_macos_intel.dmg` for Intel Macs. macOS builds use SDL2 and include a runtime shim that runs McCLIM's SDL2 event loop on the process main thread while the CLIM frame runs in a worker thread; closing the frame destroys the SDL port and closes cl-sdl2's main-thread channel so the process exits. Use the `.app` inside the DMG for GUI launches. The `.app` contains a small launcher that points `DYLD_LIBRARY_PATH` at its bundled `libzstd.1.dylib`, `libSDL2-2.0.0.dylib`, and `libSDL3.dylib`, and defaults `DISPLAY` to `:0` when no display is set. The standalone `mcclim_macos` / `mcclim_macos_intel` files are Unix executables: double-clicking one in Finder opens Terminal, which is expected. Keep the companion `.dylib` files beside a standalone executable and start it with `DYLD_LIBRARY_PATH="$(dirname ./mcclim_macos_intel)" ./mcclim_macos_intel`. Run them from a terminal only when you need the `-nw` output.

The executables are built on newer macOS runners, but task 2 lowers their deployment target to macOS 11 Big Sur, the oldest version shared by Intel and Apple silicon Macs. CI verifies the value before packaging, and the `.app` plist declares the same minimum.

To test the exact bundle and DMG locally on a Mac, run `./ask.sh` and select tasks 1, 2, and 4. Task 2 builds the SDL2 executable with `ask.d/build-mac.sh`; task 4 uses the same `ask.d/dmg.sh` script as both macOS workflows and writes `dist/mcclim/mcclim_macos_intel.dmg` on Intel and `dist/mcclim/mcclim_macos.dmg` on Apple silicon. The build steps and packaging script are now the same locally and in CI. The remaining difference is download quarantine: a file created locally has no quarantine attribute, while the same DMG downloaded from a release does.

1. Download the DMG for your Mac.
2. Clear quarantine from the downloaded DMG **before mounting it**, then verify it:

   ```sh
   DMG="$HOME/Downloads/mcclim_macos_intel.dmg"
   xattr -dr com.apple.quarantine "$DMG"
   hdiutil verify "$DMG"
   ```

   For Apple silicon, use `mcclim_macos.dmg` instead. If `xattr` reports no attribute, that is fine.
3. Open the DMG and drag `mcclim_macos.app` (Apple silicon) or `mcclim_macos_intel.app` (Intel) onto the included `Applications` shortcut.
4. Eject the disk image.
5. Clear quarantine on the copied app, then open McCLIM from `/Applications`:

   ```sh
   xattr -dr com.apple.quarantine /Applications/mcclim_macos_intel.app
   ```

   For Apple silicon, use `/Applications/mcclim_macos.app`.

The binaries and DMGs are unsigned. After downloading, macOS marks them with a quarantine attribute. Gatekeeper reports an unsigned quarantined app as **“is damaged and can’t be opened. You should move it to the Trash.”** The DMG is verified in CI, and the `.app` bundle already contains an executable `Contents/MacOS/mcclim`; `chmod +x` only fixes file permissions and does not clear this Gatekeeper message. There is no DMG-only fix for this: without Developer ID signing and notarization, the quarantine attribute must be removed locally.

If Finder opens Terminal instead of the `.app`, refresh LaunchServices:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/mcclim_macos_intel.app
open /Applications/mcclim_macos_intel.app
```

Use `/Applications/mcclim_macos.app` for Apple silicon. If macOS still prompts, use **System Settings → Privacy & Security → Open Anyway**. For a standalone binary, run `xattr -d com.apple.quarantine ./mcclim_macos` or `./mcclim_macos_intel` before launching it.

## Task Runner

```sh
./ask.sh
```

| Section | ID | Task |
|---------|----|------|
| MAC | 1 | Setup macOS (SDL2) - check/install SBCL, Quicklisp, SDL2, SDL3, and McCLIM |
| MAC | 2 | Build macOS - save an SDL2 executable and bundle the SDL dylibs |
| MAC | 3 | Dev test macOS - smoke test `-nw`, then open the SDL2 window |
| MAC | 4 | Package - create a macOS `.app` and DMG from task 2 |
| LINUX | 5 | Setup Linux (CLX) - check/install SBCL, Quicklisp, and McCLIM |
| LINUX | 6 | Build Linux - save a CLX executable |
| LINUX | 7 | Dev test Linux - smoke test `-nw`, then open the CLX window |
| WINDOWS | 8 | Setup Windows (SDL2) - check/install SBCL, Quicklisp, SDL2.dll, and McCLIM |
| WINDOWS | 9 | Build Windows - save an SDL2 executable |
| WINDOWS | 10 | Dev test Windows - smoke test `-nw`, then open the SDL2 window |
| MAINTENANCE | 11 | Clean - remove `dist/`, `bin/`, and macOS `.app` bundles |
|  | 0 | Exit |

## DMG Maker

`dmg_maker.md` documents how `ask.d/dmg.sh` builds the graphical DMG installer (background image, app icon, Applications symlink).

## Build output

Tasks 2, 6, and 9 create `dist/mcclim/` with a ~22 MB SBCL executable (plus `SDL2.dll` on Windows, and `libzstd.1.dylib`, `libSDL2-2.0.0.dylib`, and `libSDL3.dylib` on macOS). McCLIM, the Lisp runtime, and `DejaVuSans.ttf` are saved into the image, so there is no `lib/` tree and no SBCL, Quicklisp, or system font install needed on the target machine. On each GUI run the embedded font is extracted to `~/.cache/mcclim/DejaVuSans.ttf`; all text styles use that one regular face. Every build task clears `dist/` first. CI instead sets `MCCLIM_DMG_SOURCE` to its prebuilt binary so task 4 does not rebuild it. Task 11 removes `dist/`, `bin/`, and the macOS `.app` bundles.

| Project | Distribution | Size |
|---------|--------------|------|
| Racket | `bin/` executable + `lib/` runtime libraries | ~68 MB |
| McCLIM / SBCL | one self-contained executable | ~22 MB |

Copy the executable to another machine with the same OS and CPU architecture and run it there; no companion font file is needed. On Windows, copy `SDL2.dll` with it. The Debian workflow also packages it as `mcclim_0.1.0-1_amd64.deb` via `make_deb/`.

The setup tasks install SBCL when missing, bootstrap Quicklisp into `~/quicklisp`, and load McCLIM through Quicklisp. On Windows, use a POSIX shell such as Git Bash/MSYS/Cygwin.
