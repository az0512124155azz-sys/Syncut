# Syncut Alpha 0.1

Syncut is a professional video editor UI/UX fork built on the Kdenlive/MLT engine.
This source tree is based on Kdenlive and remains under the upstream GPL licensing terms.

## What is real in this alpha

- The application builds from the real Kdenlive source tree; it is **not HTML**.
- The executable output name is `syncut` / `syncut.exe`.
- Syncut branding and icon are integrated into the native application.
- The editor opens as a clean new project when no project was explicitly opened.
- Existing Kdenlive editing functionality remains real: media import, monitors, timeline, cutting, undo/redo, effects, audio mixer, subtitles, rendering and project files.
- `Ctrl+Shift+Z` opens the native Syncut AI dock.
- Redo is explicitly moved to `Ctrl+Y`.
- The AI dock does **not** download or install an AI model. It probes an already-running local Ollama-compatible endpoint at `127.0.0.1:11434` and uses an existing model if available.
- The AI chat accepts Hebrew/English prompts, asks the local model to reason precisely and answer in Hebrew, and supports text/image attachments.

## What is NOT implemented yet

The AI assistant is currently a real chat integration, but it does not yet execute arbitrary timeline edits. It deliberately does not claim that an edit was performed. Agent actions that manipulate the project will be added only when they can be wired to real Kdenlive commands with undo/redo and confirmations.

## Windows build

Run `Build-Syncut-Windows.cmd` from a Windows machine. It uses MSYS2 UCRT64 as the build environment and compiles the native C++/Qt application. This is a developer build and can take a long time because Kdenlive has many dependencies.

The scripts never install an AI model.
