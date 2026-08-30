#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"

SRC="$GITHUB_WORKSPACE/source/Syncut-Claude-Handoff"
INSTALL="$GITHUB_WORKSPACE/dist/Syncut"
BIN="$INSTALL/bin"

test -f "$BIN/syncut.exe"
test -f "$BIN/kdenlive_render.exe"

DEPLOY=""
for candidate in windeployqt6.exe windeployqt6 windeployqt.exe windeployqt; do
  if command -v "$candidate" >/dev/null 2>&1; then
    DEPLOY="$(command -v "$candidate")"
    break
  fi
done
[ -n "$DEPLOY" ] || { echo "ERROR: windeployqt was not found"; exit 20; }

"$DEPLOY" --release --qmldir "$SRC" "$BIN/syncut.exe"
"$DEPLOY" --release "$BIN/kdenlive_render.exe" || true

QMLROOT=""
for query in qtpaths6.exe qtpaths6; do
  if command -v "$query" >/dev/null 2>&1; then
    QMLROOT="$("$query" --query QT_INSTALL_QML 2>/dev/null | tr -d '\r' || true)"
    [ -n "$QMLROOT" ] && [ -d "$QMLROOT" ] && break
  fi
done
if [ -z "$QMLROOT" ] || [ ! -d "$QMLROOT" ]; then
  for candidate in /ucrt64/share/qt6/qml /ucrt64/lib/qt6/qml /ucrt64/qml; do
    if [ -d "$candidate" ]; then QMLROOT="$candidate"; break; fi
  done
fi
[ -n "$QMLROOT" ] && [ -d "$QMLROOT" ] || { echo "ERROR: Qt QML tree missing"; exit 21; }

mkdir -p "$BIN/qml"
cp -R "$QMLROOT"/. "$BIN/qml/"

for helper in kioworker.exe ktrash6.exe ktelnetservice6.exe kbuildsycoca6.exe; do
  [ ! -f "/ucrt64/bin/$helper" ] || cp -f "/ucrt64/bin/$helper" "$BIN/"
done
[ -f "$BIN/kioworker.exe" ] || { echo "ERROR: kioworker.exe missing"; exit 22; }
[ -f "$BIN/kbuildsycoca6.exe" ] || { echo "ERROR: kbuildsycoca6.exe missing"; exit 23; }

if [ -d /ucrt64/share/qt6/plugins/kf6 ]; then
  mkdir -p "$BIN/kf6"
  cp -R /ucrt64/share/qt6/plugins/kf6/. "$BIN/kf6/"
fi
[ -f "$BIN/kf6/kio/kio_file.dll" ] || { echo "ERROR: kio_file.dll missing"; exit 24; }

for data_dir in kf6 locale qlogging-categories6 knotifications6 kservices6 kservicetypes6; do
  if [ -d "/ucrt64/bin/data/$data_dir" ]; then
    mkdir -p "$BIN/data/$data_dir"
    cp -R -n "/ucrt64/bin/data/$data_dir"/. "$BIN/data/$data_dir/"
  fi
done
for data_dir in applications icons mime kxmlgui6 knotifications6 kservices6 kservicetypes6; do
  if [ -d "/ucrt64/share/$data_dir" ]; then
    mkdir -p "$BIN/data/$data_dir"
    cp -R -n "/ucrt64/share/$data_dir"/. "$BIN/data/$data_dir/"
  fi
done

MELT_SRC=""
for candidate in /ucrt64/bin/melt.exe /ucrt64/bin/melt-7.exe /ucrt64/bin/mlt-melt.exe; do
  if [ -f "$candidate" ]; then MELT_SRC="$candidate"; break; fi
done
[ -n "$MELT_SRC" ] || { echo "ERROR: MLT melt executable missing"; exit 25; }

cp -f "$MELT_SRC" "$BIN/melt.exe"
cp -f "$MELT_SRC" "$BIN/melt-7.exe"

for tool in ffmpeg.exe ffprobe.exe ffplay.exe; do
  [ -f "/ucrt64/bin/$tool" ] || { echo "ERROR: $tool missing"; exit 26; }
  cp -f "/ucrt64/bin/$tool" "$BIN/"
done

MLT_LIB_SRC=""
MLT_DATA_SRC=""
for candidate in /ucrt64/lib/mlt /ucrt64/lib/mlt-7; do
  if [ -d "$candidate" ]; then MLT_LIB_SRC="$candidate"; break; fi
done
for candidate in /ucrt64/share/mlt /ucrt64/share/mlt-7; do
  if [ -d "$candidate" ]; then MLT_DATA_SRC="$candidate"; break; fi
done
[ -n "$MLT_LIB_SRC" ] || { echo "ERROR: MLT plugin directory missing"; exit 27; }
[ -n "$MLT_DATA_SRC" ] || { echo "ERROR: MLT data directory missing"; exit 28; }

rm -rf "$INSTALL/lib/mlt" "$INSTALL/share/mlt"
mkdir -p "$INSTALL/lib/mlt" "$INSTALL/share/mlt"
cp -R "$MLT_LIB_SRC"/. "$INSTALL/lib/mlt/"
cp -R "$MLT_DATA_SRC"/. "$INSTALL/share/mlt/"

rm -rf "$INSTALL/lib/mlt-7" "$INSTALL/share/mlt-7"
mkdir -p "$INSTALL/lib/mlt-7" "$INSTALL/share/mlt-7"
cp -R "$INSTALL/lib/mlt"/. "$INSTALL/lib/mlt-7/"
cp -R "$INSTALL/share/mlt"/. "$INSTALL/share/mlt-7/"

FREI0R_SRC=""
for candidate in /ucrt64/lib/frei0r-1 /ucrt64/lib/frei0r; do
  if [ -d "$candidate" ]; then FREI0R_SRC="$candidate"; break; fi
done
[ -n "$FREI0R_SRC" ] || { echo "ERROR: Frei0r plugin directory missing"; exit 29; }

rm -rf "$INSTALL/lib/frei0r-1"
mkdir -p "$INSTALL/lib/frei0r-1"
cp -R "$FREI0R_SRC"/. "$INSTALL/lib/frei0r-1/"

if [ -d /ucrt64/share/frei0r-1 ]; then
  mkdir -p "$INSTALL/share/frei0r-1"
  cp -R /ucrt64/share/frei0r-1/. "$INSTALL/share/frei0r-1/"
fi

# Critical fix: MLT loads modules dynamically. Copy the entire UCRT64 DLL
# runtime beside syncut.exe so dependencies of libmltplus/resample/rtAudio/
# rubberband/sox and other dynamically loaded plugins cannot be missed.
dll_count=0
while IFS= read -r dll; do
  [ -f "$dll" ] || continue
  cp -f "$dll" "$BIN/"
  dll_count=$((dll_count + 1))
done < <(find /ucrt64/bin -maxdepth 1 -type f -iname '*.dll' -print | sort)

[ "$dll_count" -gt 20 ] || { echo "ERROR: Too few UCRT64 DLLs copied: $dll_count"; exit 30; }

# Second safety net: resolve transitive dependencies from every packaged
# executable and plugin.
for pass in $(seq 1 20); do
  copied=0
  while IFS= read -r file; do
    while IFS= read -r dll; do
      [ -z "$dll" ] && continue
      base="$(basename "$dll")"
      if [ -f "$dll" ] && [ ! -f "$BIN/$base" ]; then
        cp -f "$dll" "$BIN/$base"
        copied=1
      fi
    done < <(
      PATH="/ucrt64/bin:$BIN:$PATH" ldd "$file" 2>/dev/null |
      awk '/=> \/ucrt64\// {print $3} /^[[:space:]]*\/ucrt64\// {print $1}' |
      sort -u
    )
  done < <(find "$INSTALL" -type f \( -iname '*.exe' -o -iname '*.dll' \) -print)
  [ "$copied" -eq 0 ] && break
done

test -f "$INSTALL/share/mlt/profiles/dv_pal" || { echo "ERROR: MLT profile dv_pal missing"; exit 31; }
test -n "$(find "$INSTALL/lib/mlt" -maxdepth 1 -type f -iname 'libmlt*.dll' | head -1)" || { echo "ERROR: MLT modules missing"; exit 32; }
test -n "$(find "$INSTALL/lib/frei0r-1" -maxdepth 1 -type f -iname '*.dll' | head -1)" || { echo "ERROR: Frei0r DLLs missing"; exit 33; }

# Fail before GUI testing if any REAL packaged MLT dependency is unresolved.
# MSYS2 ldd reports Windows API-set forwarders (api-ms-win-* / ext-ms-win-*)
# as "not found". Those are supplied by Windows and are expected, so ignore
# only those system forwarders while still failing on real DLLs such as
# librtaudio-7.dll, librubberband-2.dll, libsox-3.dll, etc.
unresolved=0

while IFS= read -r module; do
  while IFS= read -r line; do
    [ -z "$line" ] && continue

    dll="$(printf '%s\n' "$line" | awk '{print $1}')"

    case "$dll" in
      api-ms-win-*|ext-ms-win-*)
        echo "SYSTEM API-SET (expected): $(basename "$module") -> $dll"
        continue
        ;;
    esac

    echo "ERROR: unresolved REAL MLT dependency: $module"
    echo "$line"
    unresolved=1
  done < <(
    PATH="/ucrt64/bin:$BIN:$PATH" ldd "$module" 2>/dev/null |
    grep -i 'not found' || true
  )
done < <(find "$INSTALL/lib/mlt" -maxdepth 1 -type f -iname '*.dll' -print)

[ "$unresolved" -eq 0 ] || exit 34

ICON="$SRC/data/icons/syncut.ico"
[ -f "$ICON" ] || { echo "ERROR: Syncut icon missing"; exit 35; }
cp -f "$ICON" "$INSTALL/syncut.ico"

cat > "$BIN/qt.conf" <<'QTCONF'
[Paths]
Prefix=..
Binaries=bin
Libraries=bin
LibraryExecutables=bin
Plugins=bin
QmlImports=bin/qml
Qml2Imports=bin/qml
Data=bin/data
ArchData=bin
Translations=bin/translations
QTCONF

cp -f "$BIN/qt.conf" "$BIN/qt6.conf"

echo "UCRT64 DLLs copied: $dll_count"
echo "Runtime deployment completed successfully."
