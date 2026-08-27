> **Claude handoff:** Start with [`START_HERE_CLAUDE.md`](START_HERE_CLAUDE.md).

# Syncut

Syncut is a Hebrew-first professional video editor project built from an open-source NLE foundation. The project focuses on a cleaner professional UI, full Hebrew UX, optional local AI assistance, high-quality Hebrew/English captions, and a Windows installation flow that does **not** require end users to install developer toolchains.

## Current direction

- Native C++/Qt application, not an HTML wrapper.
- Professional timeline, media bin, monitors, effects, audio mixer, subtitles, render/export and project workflows.
- Hebrew UI (`RTL`) while the time axis remains `LTR`.
- Optional AI opened with `Ctrl+Shift+Z` when an AI runtime is available.
- AI is detected before any download. No model is installed automatically.
- FFmpeg is a media-processing engine, not the AI model.
- Automatic captions target both Hebrew and English using Whisper/Vosk-style backends.

## Repository layout

- `src/` — native application source.
- `data/` — icons, application data and presets.
- `website/` — project website / GitHub Pages.
- `docs/` — architecture, AI and Windows build notes.
- `.github/workflows/windows-native.yml` — Windows cloud build.
- `.github/workflows/pages.yml` — GitHub Pages deployment.

## End-user installation policy

End users should install **Syncut only**. They should not need Visual Studio, MSYS2, Windows SDK, KDE Craft or compilers. Those tools belong in CI/build environments.

The intended release pipeline is:

1. GitHub Actions builds the native application on a Windows runner.
2. CI bundles required runtime files.
3. CI publishes a Windows artifact/release package.
4. Users download the ready-to-run installer/package.

## AI policy

AI is optional. Syncut should first detect an existing supported local runtime. If none exists, Syncut still works normally without AI. Any future model download must be explicit and show its estimated size before starting.

## Licensing

Syncut is based on Kdenlive-derived code and therefore must preserve the applicable GNU GPL terms and all third-party notices. See `LICENSES/` and `THIRD_PARTY.md`.
