#!/bin/sh
# id: 4
# group: MAC
# desc: Package - create macOS .app and DMG
. "$(dirname "$0")/lib.sh"

set -e
enter

case "$(uname -s)" in
  Darwin*) ;;
  *)
    printf "FAIL  DMG packaging requires macOS\n"
    exit 1
    ;;
esac

exe=${MCCLIM_DMG_SOURCE:-dist/mcclim/mcclim}
[ -e "$exe.exe" ] && exe="$exe.exe"
if [ -z "${MCCLIM_DMG_SOURCE:-}" ]; then
  sh "$ROOT/ask.d/build-mac.sh"
fi
if [ ! -x "$exe" ]; then
  printf "FAIL  build first with task 2\n"
  exit 1
fi

case "$(uname -m)" in
  arm64)
    name=mcclim_macos
    identifier=com.myridia.mcclim.arm64
    display="McCLIM (Apple silicon)"
    ;;
  *)
    name=mcclim_macos_intel
    identifier=com.myridia.mcclim.intel
    display="McCLIM (Intel)"
    ;;
esac

app="$name.app"
dmg="dist/mcclim/$name.dmg"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
ditto "$exe" "$app/Contents/MacOS/mcclim"
cat > "$app/Contents/MacOS/mcclim-launcher" <<'EOF'
#!/bin/sh
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ -n "$DISPLAY" ] || DISPLAY=:0
DYLD_LIBRARY_PATH="$dir${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
export DISPLAY DYLD_LIBRARY_PATH
exec "$dir/mcclim" "$@"
EOF
exe_dir=${exe%/*}
[ "$exe_dir" = "$exe" ] && exe_dir=.
for dylib in "$exe_dir"/*.dylib; do
  [ -f "$dylib" ] || continue
  ditto "$dylib" "$app/Contents/MacOS/${dylib##*/}"
done
printf 'APPL????' > "$app/Contents/PkgInfo"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>McCLIM</string>
  <key>CFBundleDisplayName</key>
  <string>$display</string>
  <key>CFBundleIdentifier</key>
  <string>$identifier</string>
  <key>CFBundleExecutable</key>
  <string>mcclim-launcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

chmod 755 "$app/Contents/MacOS/mcclim" "$app/Contents/MacOS/mcclim-launcher"
plutil -lint "$app/Contents/Info.plist"
test -x "$app/Contents/MacOS/mcclim"
test -x "$app/Contents/MacOS/mcclim-launcher"

stage=$(mktemp -d "${TMPDIR:-/tmp}/mcclim-dmg-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/$app"
ln -s /Applications "$stage/Applications"

bg="$stage/.background.png"
qlmanage -t -s 800 -o "$stage" "$ROOT/dmg_background.svg" >/dev/null 2>&1
if [ -f "$stage/dmg_background.svg.png" ]; then
  mv "$stage/dmg_background.svg.png" "$bg"
else
  sips -s format png "$ROOT/dmg_background.svg" --out "$bg" >/dev/null 2>&1 || cp "$ROOT/dmg_background.svg" "$bg"
fi

hdiutil create -volname "$name" -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"

mountpoint=$(mktemp -d "${TMPDIR:-/tmp}/mcclim-dmg.XXXXXX")
trap 'hdiutil detach "$mountpoint" >/dev/null 2>&1 || true; rmdir "$mountpoint" 2>/dev/null || true; rm -rf "$stage"' EXIT
hdiutil attach -noautoopen -mountpoint "$mountpoint" "$dmg"
sleep 2

layout_err=$(osascript <<APPLESCRIPT 2>&1 || true
tell application "Finder"
  set targetDisk to (POSIX file "$mountpoint") as alias
  open targetDisk
  delay 1
  set theWindow to front window
  set current view of theWindow to icon view
  set toolbar visible of theWindow to false
  set statusbar visible of theWindow to false
  set the bounds of theWindow to {200, 200, 800, 500}
  set theViewOptions to the icon view options of theWindow
  set arrangement of theViewOptions to not arranged
  set icon size of theViewOptions to 80
  set background picture of theViewOptions to file ".background.png"
  set position of item "$app" of theWindow to {250, 200}
  set position of item "Applications" of theWindow to {550, 200}
  set visible of item ".background.png" of theWindow to false
  update without registering applications
  delay 2
end tell
APPLESCRIPT
)
if [ -n "$layout_err" ]; then
  printf "warn  could not set DMG layout; the DMG is still valid\n%s\n" "$layout_err"
fi

hdiutil detach "$mountpoint" 2>/dev/null || hdiutil detach "$mountpoint" -force
rmdir "$mountpoint"
rm -rf "$stage"
trap - EXIT

printf "ok    %s\n" "$dmg"
