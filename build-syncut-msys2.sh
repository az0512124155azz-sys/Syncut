#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build-windows"
INSTALL="$ROOT/dist/Syncut-Alpha-0.1"

if [[ "${MSYSTEM:-}" != UCRT64 ]]; then
  echo "Run this script from MSYS2 UCRT64."
  exit 1
fi

pacman -Syu --noconfirm || true
pacman -S --needed --noconfirm \
  git make cmake ninja zip base-devel \
  mingw-w64-ucrt-x86_64-toolchain \
  mingw-w64-ucrt-x86_64-extra-cmake-modules \
  mingw-w64-ucrt-x86_64-kdenlive

rm -rf "$BUILD" "$INSTALL"
mkdir -p "$BUILD" "$INSTALL"

cmake -S "$ROOT" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF \
  -DCMAKE_INSTALL_PREFIX="$INSTALL"

cmake --build "$BUILD" --target kdenlive -j"$(nproc)"
cmake --install "$BUILD"

EXE="$INSTALL/bin/syncut.exe"
if [[ ! -f "$EXE" ]]; then
  echo "ERROR: syncut.exe was not produced."
  exit 2
fi

# Bundle Qt plugins when available.
if command -v windeployqt6 >/dev/null 2>&1; then
  windeployqt6 --release --no-translations "$EXE" || true
elif command -v windeployqt >/dev/null 2>&1; then
  windeployqt --release --no-translations "$EXE" || true
fi

# Copy runtime DLL dependencies reported by ldd.
while IFS= read -r dll; do
  [[ -f "$dll" ]] && cp -n "$dll" "$INSTALL/bin/" || true
done < <(ldd "$EXE" | awk '/=> \/ucrt64\// {print $3}' | sort -u)

# MLT runtime modules/data are needed by the editor engine.
for d in /ucrt64/lib/mlt-7 /ucrt64/share/mlt-7 /ucrt64/share/frei0r-1; do
  if [[ -d "$d" ]]; then
    rel="${d#/ucrt64/}"
    mkdir -p "$INSTALL/$(dirname "$rel")"
    cp -R "$d" "$INSTALL/$(dirname "$rel")/"
  fi
done

cat > "$INSTALL/README.txt" <<'TXT'
Syncut Alpha 0.1 native build.
This is NOT the old HTML preview.
Run bin\\syncut.exe.
No AI model is installed by this package.
TXT

cd "$ROOT/dist"
rm -f Syncut-Alpha-0.1-Windows.zip
zip -qr Syncut-Alpha-0.1-Windows.zip Syncut-Alpha-0.1

echo
echo "Build complete: $ROOT/dist/Syncut-Alpha-0.1-Windows.zip"
