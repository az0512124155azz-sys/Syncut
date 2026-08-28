#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
SRC="$GITHUB_WORKSPACE/source/Syncut-Claude-Handoff"
INSTALL="$GITHUB_WORKSPACE/dist/Syncut"
BIN="$INSTALL/bin"

test -f "$BIN/syncut.exe"

DEPLOY=""
for candidate in windeployqt6.exe windeployqt6 windeployqt.exe windeployqt; do
  if command -v "$candidate" >/dev/null 2>&1; then
    DEPLOY="$(command -v "$candidate")"
    break
  fi
done
[ -n "$DEPLOY" ] || { echo 'ERROR: windeployqt not found'; exit 20; }
"$DEPLOY" --release --qmldir "$SRC" "$BIN/syncut.exe"

QMLROOT=""
if command -v qtpaths6.exe >/dev/null 2>&1; then
  QMLROOT="$(qtpaths6.exe --query QT_INSTALL_QML 2>/dev/null | tr -d '\r' || true)"
elif command -v qtpaths6 >/dev/null 2>&1; then
  QMLROOT="$(qtpaths6 --query QT_INSTALL_QML 2>/dev/null | tr -d '\r' || true)"
fi
if [ -z "$QMLROOT" ] || [ ! -d "$QMLROOT" ]; then
  for candidate in /ucrt64/share/qt6/qml /ucrt64/lib/qt6/qml /ucrt64/qml; do
    if [ -d "$candidate" ]; then
      QMLROOT="$candidate"
      break
    fi
  done
fi
[ -n "$QMLROOT" ] && [ -d "$QMLROOT" ] || { echo 'ERROR: Qt QML tree missing'; exit 21; }
mkdir -p "$BIN/qml"
cp -R "$QMLROOT"/. "$BIN/qml/"

# KIO is not a linked-DLL-only dependency. It requires its worker executable,
# protocol plugins, and KDE Frameworks data files at runtime.
for helper in kioworker.exe ktrash6.exe ktelnetservice6.exe kbuildsycoca6.exe; do
  if [ -f "/ucrt64/bin/$helper" ]; then
    cp -f "/ucrt64/bin/$helper" "$BIN/"
  fi
done
[ -f "$BIN/kioworker.exe" ] || { echo 'ERROR: kioworker.exe missing'; exit 22; }

if [ -d /ucrt64/share/qt6/plugins/kf6 ]; then
  mkdir -p "$BIN/kf6"
  cp -R /ucrt64/share/qt6/plugins/kf6/. "$BIN/kf6/"
fi
[ -f "$BIN/kf6/kio/kio_file.dll" ] || { echo 'ERROR: kio_file.dll missing'; exit 23; }

# Windows MSYS2 stores Frameworks data under bin/data. Copy only runtime data
# and never overwrite Syncut's own installed resources with stock Kdenlive data.
for data_dir in kf6 locale qlogging-categories6 knotifications6 kservices6 kservicetypes6; do
  if [ -d "/ucrt64/bin/data/$data_dir" ]; then
    mkdir -p "$BIN/data/$data_dir"
    cp -R --no-clobber "/ucrt64/bin/data/$data_dir"/. "$BIN/data/$data_dir/"
  fi
done
for data_dir in applications icons mime kxmlgui6 knotifications6 kservices6 kservicetypes6; do
  if [ -d "/ucrt64/share/$data_dir" ]; then
    mkdir -p "$BIN/data/$data_dir"
    cp -R --no-clobber "/ucrt64/share/$data_dir"/. "$BIN/data/$data_dir/"
  fi
done

MELT_SRC=""
for candidate in /ucrt64/bin/melt.exe /ucrt64/bin/melt-7.exe /ucrt64/bin/mlt-melt.exe; do
  if [ -f "$candidate" ]; then
    MELT_SRC="$candidate"
    break
  fi
done
if [ -z "$MELT_SRC" ]; then
  MELT_SRC="$(find /ucrt64 -type f \( -iname 'melt.exe' -o -iname 'melt-7.exe' -o -iname 'mlt-melt.exe' \) | head -1 || true)"
fi
[ -n "$MELT_SRC" ] && [ -f "$MELT_SRC" ] || { echo 'ERROR: MLT melt missing'; exit 24; }
cp -f "$MELT_SRC" "$BIN/melt.exe"
cp -f "$MELT_SRC" "$BIN/melt-7.exe"

for tool in ffmpeg.exe ffprobe.exe; do
  [ -f "/ucrt64/bin/$tool" ] || { echo "ERROR: $tool missing"; exit 25; }
  cp -f "/ucrt64/bin/$tool" "$BIN/"
done

for runtime_dir in /ucrt64/lib/mlt-7 /ucrt64/share/mlt-7 /ucrt64/share/mlt /ucrt64/share/frei0r-1 /ucrt64/share/kdenlive; do
  if [ -d "$runtime_dir" ]; then
    relative="${runtime_dir#/ucrt64/}"
    mkdir -p "$INSTALL/$(dirname "$relative")"
    cp -R "$runtime_dir" "$INSTALL/$(dirname "$relative")/"
  fi
done

# Resolve the DLL dependency closure only after every executable and plugin is
# present. This includes dependencies of FFmpeg, MLT, kioworker and kio_file.
for pass in 1 2 3 4 5 6 7 8 9 10 11 12; do
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
[ -f "$ICON" ] && cp -f "$ICON" "$INSTALL/syncut.ico"

# The prefix is the package root. Explicit paths make Syncut, kioworker.exe,
# and the independent KIO probe resolve the same portable runtime tree.
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
