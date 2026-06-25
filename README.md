# Drawl

[![CI](https://github.com/mlopstapus/drawl/actions/workflows/ci.yml/badge.svg)](https://github.com/mlopstapus/drawl/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/mlopstapus/drawl)](https://github.com/mlopstapus/drawl/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Hold-to-talk voice dictation for Mac. Entirely on-device.**

Hold your configured hotkey, speak, release — your words appear wherever your cursor is. No cloud, no subscription, no microphone data leaving your machine.

<!-- Add demo GIF here -->

## Install

Download the latest release from the [Releases page](https://github.com/mlopstapus/drawl/releases/latest) and open the DMG.

**Requirements**: macOS 13 (Ventura) or later, Apple Silicon or Intel.

> On first launch, Drawl walks you through granting Microphone and Accessibility permissions, then downloads a speech model (~150 MB). After that, it runs fully offline.

## Features

- **Hold-to-talk** — hold ⌥+Space (configurable) to dictate; release to stop
- **On-device transcription** — powered by Whisper; no audio ever leaves your Mac
- **Works everywhere** — inserts text into any focused text field via Accessibility APIs
- **Minimal footprint** — lives in the menu bar; no Dock icon, no main window
- **Transcription history** — last 30 days, searchable from the menu bar

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for prerequisites, build instructions, and how to run tests.

```bash
git clone https://github.com/mlopstapus/drawl.git
open drawl/Drawl.xcodeproj
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

By participating in this project you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).

## Security

To report a security vulnerability, please follow the process in [SECURITY.md](SECURITY.md). Do not open a public issue.

## License

MIT — see [LICENSE](LICENSE).
