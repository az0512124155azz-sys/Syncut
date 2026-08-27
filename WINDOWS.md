# Windows build and installation

## Important distinction

Developer tools belong on the build machine, not on normal user computers.

The previous local experiments installed components such as Visual Studio 2022, Developer Command Prompt shortcuts, Windows Performance Analyzer/Recorder, GPUView and MSYS2 shells. Those are development/diagnostic tools; they are not Syncut features and are not meant to ship as part of the end-user installer.

## Desired release flow

Use GitHub Actions to build Windows artifacts remotely. A user should ultimately download one prepared Syncut installer/package.

The included workflow is an **alpha CI workflow** and may require dependency/version fixes as the native fork evolves. It intentionally keeps build tooling inside the GitHub runner.
