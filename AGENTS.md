# AGENTS.md — mcclim

## What this is
Minimal Common Lisp GUI hello-world program built with McCLIM (a Common Lisp implementation of CLIM).

The window shows “Hello, world!” with a **Quit** button.

## Stack
- Common Lisp (SBCL)
- McCLIM
- Quicklisp

## Structure
- `main.lisp` — GUI entry point; loads Quicklisp/McCLIM, selects the CLX or SDL2 backend, defines the application frame, and runs it
- `sdl2-runtime.lisp` — loaded only when SDL2 is selected; defines `reset-sdl2-user-event-id`, centers/borders managed frames, on macOS SBCL moves McCLIM's SDL2 loop to the process main thread so a native window appears, and closes the port and cl-sdl2 main-thread channel on exit
- `sdl2.sh` — helper used by setup and the Windows workflow: pins McCLIM 1.0.0 in `~/quicklisp/local-projects`, installs Homebrew `sdl2`/`sdl3` and pins a `cl-sdl2` with the Apple Silicon spec on macOS, and downloads `SDL2.dll` into `vendor/sdl2/` on Windows
- `ask.sh` — task runner menu grouped by OS: MAC, LINUX, WINDOWS, then MAINTENANCE; packaging lives under MAC
- `ask.d/lib.sh` — shared task helpers
- `ask.d/setup-mac.sh` — task 1: macOS setup with SDL2/SDL3
- `ask.d/build-mac.sh` — task 2: build the macOS SDL2 executable
- `ask.d/dev-test-mac.sh` — task 3: macOS SDL2 dev test (`-nw` smoke test, then GUI)
- `ask.d/dmg.sh` — task 4 and both macOS workflows: build a macOS `.app` bundle and DMG; local task 4 uses task 2, while `MCCLIM_DMG_SOURCE` selects a prebuilt input binary in CI
- `ask.d/setup-linux.sh` — task 5: Linux setup
- `ask.d/build-linux.sh` — task 6: build the Linux CLX executable
- `ask.d/dev-test-linux.sh` — task 7: Linux CLX dev test (`-nw` smoke test, then GUI)
- `ask.d/setup-windows.sh` — task 8: Windows setup with SDL2.dll
- `ask.d/build-windows.sh` — task 9: build the Windows SDL2 executable
- `ask.d/dev-test-windows.sh` — task 10: Windows SDL2 dev test (`-nw` smoke test, then GUI)
- `ask.d/setup.sh` — shared setup implementation, hidden from the menu
- `ask.d/build.sh` — shared executable builder used by tasks 2, 6, 9 and CI
- `ask.d/dev-test.sh` — shared dev-test helper
- `ask.d/run.sh` — direct `sbcl --script main.lisp` helper, hidden from the menu
- `ask.d/clean.sh` — task 11: remove `dist/`, `bin/`, and the macOS `.app` bundles created by task 4
- `README.md` — project title, logo, and commands
- `AGENTS.md` — this project guide
- `LICENSE` — project license
- `make_deb/` — Debian packaging (`dpkg-buildpackage`) for the prebuilt executable; `make_deb/src/mcclim` is copied in by the Debian workflow; `make_deb/README.md` documents the staging/build mechanics
- `.gitignore` — Common Lisp, build-output, and `vendor/` ignore rules
- `.github/scripts/make-windows-launcher.ps1` — compiles a GUI-subsystem .NET launcher, appends a ZIP payload containing the raw SBCL image and `SDL2.dll`, and writes the single-file `mcclim_windows.exe`
- `dmg_maker.md` — how the graphical DMG installer is built (background, icon layout, Applications symlink)
- `dmg_background.svg` — 800x500 background image for the DMG installer (drag-to-Applications graphic)
- `mcclim.svg` — README logo; also used by the project page
- `pages/public/` — GitHub Pages site (`index.html`, `style.css`, `img/mcclim.svg`), deployed by `pages.yml`

## Run
```sh
./ask.sh
```

Tasks 1, 5, and 8 check for `sbcl`, a downloader (`curl`/`wget`), and Quicklisp, installs SBCL when missing (`apt-get`, `dnf`, or `pacman` on Linux; Homebrew on macOS; Chocolatey, Scoop, or winget under a POSIX shell on Windows), bootstraps Quicklisp into `~/quicklisp`, runs `sdl2.sh`, and loads McCLIM. Tasks 2, 6, and 9 select the backend per platform (macOS and Windows use SDL2, Linux uses CLX), then read `DejaVuSans.ttf` into a byte vector at build time, save that vector with the executable via `sb-ext:save-lisp-and-die` in `bin/`, lower the macOS Mach-O deployment target to 11.0 with `xcrun vtool`, copy Homebrew's `libzstd.1.dylib` and, for SDL2 builds, `libSDL2-2.0.0.dylib` and `libSDL3.dylib` beside the executable, and copy the executable (and `SDL2.dll` on Windows) to `dist/mcclim/`. `main.lisp` writes the embedded bytes to `~/.cache/mcclim/DejaVuSans.ttf` and repoints `*families/faces*` there, so the target machine needs no font file. Tasks 3, 7, and 10 run `sbcl --script main.lisp -nw` as a smoke test and then `sbcl --script main.lisp` for the GUI on the matching platform. Every build clears `dist/` with task 11 first. Task 4 requires macOS; CI sets `MCCLIM_DMG_SOURCE` to reuse its prebuilt binary. Task 4 stages `mcclim_macos_intel.app` or `mcclim_macos.app` with `ditto`, adds a `mcclim-launcher` shell script that sets `DYLD_LIBRARY_PATH` and defaults `DISPLAY` to `:0`, bundles every `.dylib` beside the executable, adds `PkgInfo` and `Contents/Resources`, lints the plist, checks both executables, stages the app with an `Applications` symlink, creates a `UDZO` DMG with `hdiutil`, verifies it, and mounts it once to confirm the bundle survived. Task 11 removes `dist/`, `bin/`, and the macOS `.app` bundles created by task 4.

`main.lisp` defaults to McCLIM's SDL2 backend (`:sdl2-soft`) on Windows, uses SDL2 for the macOS build and dev-test tasks, and uses CLX for the Linux build and dev-test task. Windows needs `SDL2.dll` beside the executable or on `PATH`; macOS needs the bundled SDL dylibs or the Homebrew ones on `DYLD_LIBRARY_PATH`. Set `MCCLIM_BACKEND=sdl2` or `MCCLIM_BACKEND=clx` to override the task default. `cl-sdl2` allocates `*user-event-id*` in foreign memory at load time, which a saved core cannot preserve, so `main()` calls `reset-sdl2-user-event-id` from `sdl2-runtime.lisp` at runtime before creating a port. The file is loaded only after `mcclim-sdl2` is quickloaded, so CLX builds on macOS, Linux, and FreeBSD never require the `sdl2` or `plus-c` packages. It also forces managed SDL2 frames to be bordered and centers them before they are shown; unmanaged menu/popup sheets keep McCLIM's pointer-based placement. On macOS SBCL it overrides `%init-port` so `sdl2:init` establishes the cl-sdl2 main-thread channel and `%loop-port` runs on the process main thread; `main.lisp` runs the CLIM frame in a worker thread and joins it so the main thread stays free for SDL. Without both halves McCLIM starts SDL but never shows a window. When the frame exits, `quit-sdl2-port` destroys the SDL port and calls `sdl2:quit` to close cl-sdl2's main-thread channel; otherwise the window closes but the app stays running. The Windows image uses `:application-type :gui` so GUI runs never create a console window; `-nw` calls `AttachConsole` and writes with `WriteFile` so stdout still works. `sdl2.sh` converts a Windows-style `HOME` to a POSIX path for shell tools while leaving SBCL's environment unchanged. The Windows image uses `:compression nil` because the Windows SBCL has no zstd support; other platforms keep `:compression t`.

Direct command:
```sh
sbcl --script main.lisp
```

Built executable with no window:
```sh
./dist/mcclim/mcclim -- -nw
```

The `--` stops SBCL from parsing the flag as its own option. `-nw`, `--nw`, and `--no-window` print `Hello, world!` to stdout instead of opening the McCLIM window.

## Workflows
Release steps publish on every `control.yml` run: manual input wins, then a pushed tag, then the fallback `v0.1.0` set by the `tag` job. Branch pushes therefore release with `v0.1.0`; direct dispatch of a platform workflow with no tag still skips release.
- `.github/workflows/control.yml` — single build gate; push to `main`, any tag, and manual dispatch. A `tag` job resolves the release tag for all build jobs. `linux`, `debian`, `windows`, `macos`, `macos_intel`, and `freebsd` are enabled; `msix` and `pages` are commented out.
- `.github/workflows/linux.yml` — `workflow_call` + `workflow_dispatch`. Install step installs SBCL/curl and bootstraps Quicklisp with McCLIM, then builds inline, smoke-tests the `-nw` output, uploads the single `mcclim_linux` binary to the release with `DejaVuSans.ttf` embedded in the image. It deliberately omits `ql:add-to-init-file` — that call prompts for Enter and fails on CI's closed stdin; `main.lisp` loads `~/quicklisp/setup.lisp` itself. `ask.d/setup.sh` writes the same init block to `~/.sbclrc` itself instead of calling the prompt.
- `.github/workflows/debian.yml` — `workflow_call` + `workflow_dispatch`. Builds the executable, copies it into `make_deb/src/`, runs `dpkg-buildpackage -us -uc -b`, and uploads `mcclim_0.1.0-1_amd64.deb`.
- `.github/workflows/macos.yml` — `workflow_call` + `workflow_dispatch`. Sets `MCCLIM_BACKEND=sdl2`, runs `ask.d/setup.sh` and `ask.d/build-mac.sh` on `macos-latest`, renames the executable, then calls `ask.d/dmg.sh` with `MCCLIM_DMG_SOURCE=dist/mcclim/mcclim_macos` so CI uses the same build, bundle, and DMG code as local tasks 1, 2, and 4, and uploads `mcclim_macos`, `mcclim_macos.dmg`, `libzstd*.dylib`, and `libSDL*.dylib`. The bundle uses `com.myridia.mcclim.arm64`; the DMG is unsigned, so Gatekeeper may report a quarantined copy as damaged until its quarantine attribute is removed.
- `.github/workflows/macos_intel.yml` — `workflow_call` + `workflow_dispatch`. Sets `MCCLIM_BACKEND=sdl2`, runs `ask.d/setup.sh` and `ask.d/build-mac.sh` on `macos-15-intel`, renames the executable, then calls `ask.d/dmg.sh` with `MCCLIM_DMG_SOURCE=dist/mcclim/mcclim_macos_intel` so CI uses the same build, bundle, and DMG code as local tasks 1, 2, and 4, and uploads `mcclim_macos_intel`, `mcclim_macos_intel.dmg`, `libzstd*.dylib`, and `libSDL*.dylib`. The bundle uses `com.myridia.mcclim.intel`; the DMG is unsigned, so clear `com.apple.quarantine` on the downloaded DMG before mounting it, then on the copied app.
- `.github/workflows/windows.yml` — `workflow_call` + `workflow_dispatch`. Installs SBCL with Chocolatey and falls back to the official SBCL MSI if the Chocolatey feed fails, pins McCLIM 1.0.0 via `sdl2.sh`, builds the raw image in Git Bash with `:compression nil :application-type :gui`, wraps the raw image and `SDL2.dll` into a single-file `mcclim_windows.exe` launcher via `.github/scripts/make-windows-launcher.ps1`, and uploads the launcher, `mcclim_windows_raw.exe`, `SDL2.dll`, plus `mcclim_windows.zip` containing the raw pair so the DLL is not missed.
- `.github/workflows/freebsd.yml` — `workflow_call` + `workflow_dispatch`. Builds in a FreeBSD VM, uploads `mcclim_freebsd`.
- `.github/workflows/pages.yml` — `workflow_call` + `workflow_dispatch`, deploys `pages/public` to GitHub Pages via `configure-pages` / `upload-pages-artifact` / `deploy-pages`. The `myridia` guard lives only in `control.yml`.

## Patterns
- All macOS DMGs are built by `ask.d/dmg.sh`; local task 4 runs task 2 first, while workflows pass a prebuilt binary through `MCCLIM_DMG_SOURCE`. Every DMG contains the `.app` plus an `Applications` symlink to `/Applications` so Finder shows the drag-to-install target.
- The macOS builder copies Homebrew SDL dylibs directly and rewrites them to `@rpath`; SDL is loaded at runtime, so it never appears in the saved executable's `otool -L` output.
- The `.app` launches through `mcclim-launcher`, which sets `DYLD_LIBRARY_PATH` and defaults `DISPLAY` to `:0` only when no display is set; SSH X11 forwarding keeps precedence.

## Conventions
- Keep the README logo as its first line.
- No code comments unless asked.
- Do not compile or run Lisp code; the user builds and runs it.
- Apply workspace permissions after edits: `chown -R 1000:33 <project>` and `chmod -R g+w <project>`.
