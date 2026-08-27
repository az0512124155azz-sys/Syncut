# Optional AI integration

Syncut must remain fully usable without AI.

## Detection first

Before offering any AI installation, detect supported local runtimes. If a compatible runtime/model is already present, reuse it instead of downloading another model.

## No silent heavy downloads

- Default: AI disabled.
- Show model/runtime size before download.
- Never install Ollama (or any other runtime) merely because the UI has an AI button.
- The AI control should be hidden or clearly disabled when no provider is configured.

## Language bridge

Hebrew user message → optional internal English translation → model → tool/action plan → editor → Hebrew response.

## FFmpeg

FFmpeg is not the AI. It is a multimedia toolkit that may be used for codecs, analysis, filters, transcodes, proxies, audio extraction and rendering-related jobs.
