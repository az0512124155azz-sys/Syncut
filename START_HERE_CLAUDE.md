# START HERE — Syncut handoff for Claude

You are taking over development of **Syncut**, a Hebrew-first professional desktop video editor forked from Kdenlive.

## The user's non-negotiable goal

Produce a **real Windows desktop application and installer**, not an HTML preview, not a browser wrapper, and not a script that asks the end user to install Visual Studio/MSYS2/KDE Craft/Python/compilers.

The user should eventually download one Windows installer, run it, and get Syncut.

## Read these first

1. `README.md`
2. `SYNCUT_ALPHA.md`
3. `docs/ARCHITECTURE.md`
4. `docs/AI.md`
5. `docs/WINDOWS.md`
6. `design-reference/Syncut-target-ui.png`
7. `branding/Syncut-logo.png`
8. `website/index.html`

## Current codebase

This repository contains the full Kdenlive-derived C++/Qt source tree plus initial Syncut changes.

Existing Syncut-specific changes include:

- executable output renamed to `syncut.exe` (`src/CMakeLists.txt`)
- Syncut branding in application metadata
- initial dark Syncut visual styling
- `Ctrl+Shift+Z` action for the Syncut AI dock
- initial local AI assistant widget in `src/syncut/`
- no automatic AI model installation
- Windows CI workflow under `.github/workflows/windows-native.yml`
- website and project documentation

Do not throw these changes away. Inspect them and improve them.

## UI target

`design-reference/Syncut-target-ui.png` is the visual target.

Important principles:

- Hebrew RTL interface, but timeline time direction stays left-to-right.
- Professional NLE density, but not crowded.
- Fresh/empty app on first launch. Do NOT preload sample clips, demo projects, sample timelines, or fake media.
- New project/open project entry state should be clean.
- Project bin on the left.
- Source/project monitors in the upper workspace.
- Large real multitrack timeline below.
- Audio mixer on the right when appropriate.
- Workspaces/panels should be contextual so the UI is not permanently overloaded.
- No fake buttons. A visible action must call a real underlying Kdenlive/MLT action.
- Keep all professional Kdenlive capabilities reachable even if advanced tools live in menus/workspaces.

## Features that must remain available from upstream Kdenlive

Do not regress the underlying editor. Preserve or expose the real features including, where supported by upstream:

- media/project bin and folders
- video/audio/image import
- timeline editing
- multiple video/audio tracks
- subtitle tracks
- trimming, razor/split, ripple and standard NLE tools
- transitions/compositions
- effect stack + keyframes
- masks/rotoscoping
- color correction and scopes
- audio mixer and audio effects
- proxies
- stabilization
- scene cut analysis
- speed/time remapping
- title editor
- guides/markers
- project archive/cache/backup
- render/export presets and queue
- capture/recording features supported by upstream
- speech-to-text/subtitles
- OTIO or other interchange support already available upstream

The goal is to redesign access to these features, not delete them.

## Automatic subtitles

Make the existing speech-to-text workflow particularly good for **Hebrew and English**.

Requirements:

- explicit Hebrew mode
- explicit English mode
- automatic language detection option
- Whisper support already present upstream should be used rather than re-invented if possible
- Hebrew subtitles displayed RTL
- English subtitles displayed LTR
- punctuation and sensible segmentation
- configurable max subtitle length / line count
- SRT / VTT / ASS export where supported
- expose model/status/download requirements clearly
- do not silently download multi-GB models without explicit user consent

## Syncut AI

Shortcut: **Ctrl+Shift+Z** toggles the AI chat.

Redo must use another normal shortcut such as Ctrl+Y if the conflict exists.

AI is optional. Syncut must be a complete editor without AI.

At installation/first-run:

1. detect supported local AI runtimes/models that already exist
2. if an existing compatible runtime/model is found, offer to connect to it
3. if not found, ask whether the user wants AI at all
4. if the user says no, install no model/runtime
5. never silently install Ollama or any other heavy model/runtime

The AI chat should support attachments:

- images
- documents
- scripts/storyboards
- subtitle files
- other useful project references

Desired language flow:

Hebrew user request -> translate/normalize to English for the model when needed -> model/tool plan -> execute real editor actions -> translate response/status back to Hebrew.

Do not translate filenames, timecodes, code, paths, or technical identifiers unnecessarily.

The AI eventually needs to operate the real editor from A to Z through an **explicit command/tool layer**, not by mouse-coordinate automation.

Build an action API around real editor operations, for example:

- import media
- create bins
- create tracks
- insert/move/trim/split clips
- add transitions
- apply effects
- set keyframes
- create titles/templates
- generate/add/edit subtitles
- normalize/mix audio
- create proxies
- set project properties
- render/export

Every mutating AI action must integrate with undo/redo and should request approval for broad/destructive operations.

## FFmpeg clarification

FFmpeg is **not the AI**. It is a media-processing engine/toolset.

Use FFmpeg/MLT/Kdenlive capabilities where appropriate for media processing. Do not present FFmpeg as a language model.

## Windows build/distribution — critical

The user explicitly does NOT want compiler/build tools installed on their PC.

Therefore:

- build in GitHub Actions or another clean CI Windows builder
- the CI environment may install Craft/MSYS2/Visual Studio/etc. as build dependencies
- the released user package must bundle required runtime DLLs/resources
- publish a ready-to-run Windows artifact/installer
- end user installation must not install Visual Studio, MSYS2, Windows SDK debugging tools, KDE Craft, Python, Ninja, CMake, or compilers

### First task for you

Make `.github/workflows/windows-native.yml` actually produce a working Windows package from this repo.

Do not assume the existing workflow is correct. Validate:

- dependency strategy
- target name
- output name `syncut.exe`
- runtime DLL deployment
- Qt/KDE plugins
- MLT modules/profiles
- Frei0r/effects
- translations/resources
- icons/branding
- launch from a clean Windows machine

Then create a proper installer artifact (NSIS is acceptable) named like:

`Syncut-Alpha-0.1-Windows-x64-Setup.exe`

CI must also upload a portable ZIP for debugging.

## Definition of done for Alpha 0.1

A Windows user can:

1. install Syncut with one installer
2. launch it without installing development tools
3. see an empty/new Syncut project (no fake sample footage)
4. import a real video/audio/image file
5. put it on the real timeline
6. play it in the real monitor
7. split/trim/move clips
8. save/reopen the project
9. use at least one real effect
10. create/edit subtitles
11. render/export a real video
12. open Syncut AI with Ctrl+Shift+Z if AI integration is enabled

Anything not actually connected must not masquerade as working.

## Do not do these things

- Do not replace the app with HTML/Electron just to make packaging easier.
- Do not install upstream Kdenlive and call it Syncut.
- Do not preload demo media.
- Do not add fake timeline clips/screenshots.
- Do not silently install an AI runtime/model.
- Do not make the user compile Kdenlive locally.
- Do not remove professional Kdenlive functionality just to simplify the UI.
- Do not overwrite licensing notices from the Kdenlive-derived code.

## How to work with the user

The user wants the shortest possible operational instructions. Prefer producing build artifacts and one-click installers over giving them 20 terminal commands.

When a build fails, fix the project/CI rather than asking the user to install another developer tool locally.
