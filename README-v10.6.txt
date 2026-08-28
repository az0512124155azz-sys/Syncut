Syncut v10.6 Local AI Fix

Upload ONLY these three files to the repository root, replacing the existing files:
- syncut-source.part01
- syncut-source.part02
- syncut-source.part03

Do not change build-syncut.yml for this patch.

What changed:
- Removed Gemini, NVIDIA, API-key and cloud-provider code from Syncut AI.
- Syncut AI is local-first and always leaves the editor usable.
- Detects packaged FFmpeg and MLT.
- Detects Ollama locally at 127.0.0.1:11434 and uses an installed local model when available.
- Detects Bionic on Windows and probes the local LM Studio-compatible runtime only at 127.0.0.1:1234.
- If neither optional local runtime is active, Syncut falls back to its built-in local editor planner.
- No external endpoint is contacted by this component.
