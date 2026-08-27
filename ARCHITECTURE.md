# Syncut architecture

## Native editor

Syncut keeps the mature editing engine and project model of the open-source NLE foundation while redesigning the user-facing workspace.

Core layers:

1. **Qt UI** — Hebrew-first interface, workspaces and panels.
2. **Timeline/project layer** — clips, tracks, effects, transitions, undo/redo and project state.
3. **MLT** — media timeline and rendering framework.
4. **FFmpeg ecosystem** — codecs, probing, filters and media conversion where used by the stack.
5. **Optional AI bridge** — translates user intent into approved editor actions.

## AI agent rules

- AI is optional.
- `Ctrl+Shift+Z` opens the assistant when enabled.
- The assistant can receive text, images, documents and scripts.
- Hebrew requests may be normalized/translated to English internally for model compatibility.
- Model output is translated back to Hebrew for the user.
- AI actions should call native editor commands rather than editing project files blindly.
- Meaningful destructive or high-impact actions require confirmation.
- Every AI edit must participate in Undo/Redo.

## Captions

Primary languages: Hebrew and English.

Expected pipeline:

Audio → speech recognition → language-aware punctuation → segmentation → overlap cleanup → RTL/LTR styling → user review → SRT/VTT/ASS or timeline subtitle track.
