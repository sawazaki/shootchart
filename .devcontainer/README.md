# Dev Container

This container is for editing and AI-assisted development from VS Code.

Xcode, iPad Simulator, signing, provisioning profiles, and App Store submission stay on macOS. Open this same project folder in Xcode on the Mac side when you want to build, preview, run, or archive the iPad app.

## Included in the Container

- Git and GitHub CLI
- Node.js LTS
- Claude Code CLI
- Codex CLI
- ripgrep, jq, curl, zsh
- VS Code Swift and LLDB extensions

Note: this is a Linux container, so it does not include Apple's iPadOS SDK, SwiftUI previews, or the iOS Simulator. Swift language features in VS Code are useful for editing, but Xcode on macOS remains the source of truth for iPad app diagnostics and builds.

## First Run

1. Open this folder in VS Code.
2. Run `Dev Containers: Reopen in Container`.
3. Wait for `postCreateCommand` to install Claude Code and Codex.
4. Authenticate inside the container:

```sh
claude
codex
```

## Build Workflow

Use the container for code edits and CLI assistance:

```sh
claude
codex
```

Use macOS/Xcode for Apple-specific tasks:

```sh
open -a Xcode .
```

If you prefer terminal builds, run `xcodebuild` from the Mac terminal, not from inside this Linux container.
