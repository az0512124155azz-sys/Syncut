#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
SRC="$GITHUB_WORKSPACE/source/Syncut-Claude-Handoff"
INSTALL="$GITHUB_WORKSPACE/dist/Syncut"
BIN="$INSTALL/bin"

test -f "$BIN/syncut.exe"
test -f "$BIN/kdenlive_render.exe"

# Qt application deployment.
DEPLOY=""
for candidate in windeployqt6.exe windeployqt6 windeployqt.exe windeployqt; do
  if command -v "$candidate" >/dev/null 2>&1; then
    DEPLOY="$(command -v "$candidate")"
    break
  fi
done
[ -n "$DEPLOY" ] || { echo 'ERROR: windeployqt was not found'; exit 20; }
"$DEPLOY" --release --qmldir "$SRC" "$BIN/syncut.exe"
"$DEPLOY" --release "$BIN/kdenlive_render.exe" || true

# Kdenlive uses QML modules that static scanning does not always discover.
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
[ -n "$QMLROOT" ] && [ -d "$QMLROOT" ] || { echo 'ERROR: Qt QML tree missing'; exit 21; }
mkdir -p "$BIN/qml"
cp -R "$QMLROOT"/. "$BIN/qml/"

# KIO file protocol runtime.
for helper in kioworker.exe ktrash6.exe ktelnetservice6.exe kbuildsycoca6.exe; do
  [ ! -f "/ucrt64/bin/$helper" ] || cp -f "/ucrt64/bin/$helper" "$BIN/"
done
[ -f "$BIN/kioworker.exe" ] || { echo 'ERROR: kioworker.exe missing'; exit 22; }
[ -f "$BIN/kbuildsycoca6.exe" ] || { echo 'ERROR: kbuildsycoca6.exe missing'; exit 23; }

if [ -d /ucrt64/share/qt6/plugins/kf6 ]; then
  mkdir -p "$BIN/kf6"
  cp -R /ucrt64/share/qt6/plugins/kf6/. "$BIN/kf6/"
fi
[ -f "$BIN/kf6/kio/kio_file.dll" ] || { echo 'ERROR: kio_file.dll missing'; exit 24; }

# KDE Frameworks runtime metadata. Do not copy stock /share/kdenlive: the
# source build already installed Syncut's own modified resources there.
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

# MLT command-line tool.
MELT_SRC=""
for candidate in /ucrt64/bin/melt.exe /ucrt64/bin/melt-7.exe /ucrt64/bin/mlt-melt.exe; do
  if [ -f "$candidate" ]; then MELT_SRC="$candidate"; break; fi
done
[ -n "$MELT_SRC" ] || { echo 'ERROR: MLT melt executable missing'; exit 25; }
cp -f "$MELT_SRC" "$BIN/melt.exe"
cp -f "$MELT_SRC" "$BIN/melt-7.exe"

# FFmpeg tools used by proxies, analysis, transcoding, preview, and rendering.
for tool in ffmpeg.exe ffprobe.exe ffplay.exe; do
  [ -f "/ucrt64/bin/$tool" ] || { echo "ERROR: $tool missing"; exit 26; }
  cp -f "/ucrt64/bin/$tool" "$BIN/"
done

# Current MSYS2 MLT layout is lib/mlt + share/mlt. Resolve candidates instead
# of relying on an old version-suffixed directory.
MLT_LIB_SRC=""
MLT_DATA_SRC=""
for candidate in /ucrt64/lib/mlt /ucrt64/lib/mlt-7; do
  if [ -d "$candidate" ]; then MLT_LIB_SRC="$candidate"; break; fi
done
for candidate in /ucrt64/share/mlt /ucrt64/share/mlt-7; do
  if [ -d "$candidate" ]; then MLT_DATA_SRC="$candidate"; break; fi
done
[ -n "$MLT_LIB_SRC" ] || { echo 'ERROR: MLT plugin directory missing'; exit 27; }
[ -n "$MLT_DATA_SRC" ] || { echo 'ERROR: MLT data directory missing'; exit 28; }
rm -rf "$INSTALL/lib/mlt" "$INSTALL/share/mlt"
mkdir -p "$INSTALL/lib/mlt" "$INSTALL/share/mlt"
cp -R "$MLT_LIB_SRC"/. "$INSTALL/lib/mlt/"
cp -R "$MLT_DATA_SRC"/. "$INSTALL/share/mlt/"

# Frei0r plugins are loaded dynamically by MLT. They must be bundled and the
# application sets FREI0R_PATH to this exact directory before MLT starts.
FREI0R_SRC=""
for candidate in /ucrt64/lib/frei0r-1 /ucrt64/lib/frei0r; do
  if [ -d "$candidate" ]; then FREI0R_SRC="$candidate"; break; fi
done
[ -n "$FREI0R_SRC" ] || { echo 'ERROR: Frei0r plugin directory missing'; exit 29; }
rm -rf "$INSTALL/lib/frei0r-1"
mkdir -p "$INSTALL/lib/frei0r-1"
cp -R "$FREI0R_SRC"/. "$INSTALL/lib/frei0r-1/"
if [ -d /ucrt64/share/frei0r-1 ]; then
  mkdir -p "$INSTALL/share/frei0r-1"
  cp -R /ucrt64/share/frei0r-1/. "$INSTALL/share/frei0r-1/"
fi

# Validate the exact runtime families before resolving DLL dependencies.
test -f "$INSTALL/share/mlt/profiles/dv_pal" || { echo 'ERROR: MLT profile dv_pal missing'; exit 30; }
test -n "$(find "$INSTALL/lib/mlt" -maxdepth 1 -type f -iname 'libmlt*.dll' | head -1)" || { echo 'ERROR: MLT module DLLs missing'; exit 31; }
test -n "$(find "$INSTALL/lib/frei0r-1" -maxdepth 1 -type f -iname '*.dll' | head -1)" || { echo 'ERROR: Frei0r DLLs missing'; exit 32; }

# Resolve the complete UCRT64 DLL dependency closure after all executables and
# dynamic plugins are present.
for pass in $(seq 1 16); do
  copied=0
  while IFS= read -r file; do
    while IFS= read -r dll; do
      [ -z "$dll" ] && continue
      base="$(basename "$dll")"
      if [ -f "$dll" ] && [ ! -f "$BIN/$base" ]; then
        cp -f "$dll" "$BIN/$base"
        echo "Copied dependency: $base"
        copied=1
      fi
    done < <(ldd "$file" 2>/dev/null | awk '/=> \/ucrt64\// {print $3}' | sort -u)
  done < <(find "$INSTALL" -type f \( -iname '*.exe' -o -iname '*.dll' \) -print)
  [ "$copied" -eq 0 ] && break
done

ICON="$SRC/data/icons/syncut.ico"
[ -f "$ICON" ] || { echo 'ERROR: Syncut icon missing'; exit 33; }
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

for tool in syncut.exe kdenlive_render.exe kioworker.exe melt.exe ffmpeg.exe ffprobe.exe; do
  if [ -f "$BIN/$tool" ]; then
    echo "===== ldd: $tool ====="
    ldd "$BIN/$tool" 2>/dev/null || true
  fi
done

echo 'Runtime deployment completed.'
