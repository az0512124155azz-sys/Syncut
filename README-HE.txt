Syncut v10 - Fix + AI

מה תוקן:
- MLT melt.exe נארז ומזוהה אוטומטית, בלי חלון בחירת קובץ.
- Qt/QML runtime מלא כולל QtQuick.Controls.
- המתקין סוגר Syncut ישן לפני החלפת DLLs ומנקה runtime ישן.
- אייקון Windows חדש: סמל Syncut גדול ללא הטקסט הקטן מסביב.
- מסך פתיחה חדש, גדול, כהה ומקצועי בעברית, ללא Made by KDE.
- Syncut AI פונקציונלי עם Ctrl+Shift+Z.
- AI: Ollama מקומי, Gemini, OpenAI-compatible/NVIDIA.
- קבצי טקסט ותמונות כקלט ל-AI.
- פעולות בטוחות בעורך: Undo, Redo, Save, Render, Razor, Select, Subtitle, Mark In/Out, Snap.

קבצים להחלפה ב-GitHub:
1. .github/workflows/build-syncut.yml
2. installer.nsi בשורש המאגר
3. syncut-source.part01 בשורש המאגר
4. syncut-source.part02 בשורש המאגר
5. syncut-source.part03 בשורש המאגר

לא צריך להעלות את FFmpeg-master(2).zip. Build v10 משתמש בחבילת FFmpeg/MLT הבינארית של MSYS2, שהיא מה שנדרש ל-Windows runtime.
