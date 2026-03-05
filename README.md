# ⚡ FlashMLX

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple)](https://github.com/GuLu9527/FlashMLX)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://github.com/GuLu9527/FlashMLX)
[![License](https://img.shields.io/github/license/GuLu9527/FlashMLX)](LICENSE)
[![Release](https://img.shields.io/github/v/release/GuLu9527/FlashMLX)](https://github.com/GuLu9527/FlashMLX/releases)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2FM2%2FM3%2FM4-blue)](https://github.com/GuLu9527/FlashMLX)

[中文文档](README_CN.md)

A lightweight macOS menubar app for managing local MLX model inference servers.

**~2MB binary** — menubar-resident, one-click start/stop.

## Features

- 🔍 **Auto-scan** MLX models from HuggingFace cache (`~/.cache/huggingface/hub/`)
- 🚀 **One-click start/stop** MLX inference server (`mlx_lm.server` / `mlx-openai-server`)
- 🧩 **Embedding model support** — auto-detect & serve embedding models via `/v1/embeddings`
- ⚙️ **Configure** context length (2K–128K), port, model type, Python path
- 📊 **Real-time monitoring** — server status, uptime, memory RSS
- 📋 **Quick Actions** — copy API URL / cURL command with one click
-  **Python Verification** — validate mlx-lm installation from Settings
- 🚀 **Launch at Login** — optional auto-start via SMAppService
- � **Detach to Window** — popover can detach to a resizable floating window
- 🔔 **Notifications** — system notifications on server start/stop/error
- 🌐 **i18n** — English + Chinese, follows system language
- 🛡️ **Process management** — multi-instance prevention, orphan cleanup, port conflict auto-resolve
- 🪶 **Lightweight** — ~2MB, no Electron, pure Swift + SwiftUI

## Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon Mac (M1/M2/M3/M4)
- Python 3.x with `mlx-lm` installed
- For embedding models: `mlx-openai-server` (`pip install mlx-openai-server`)

## Quick Start

### 1. Python Environment

```bash
python3 -m venv ~/mlx-env
~/mlx-env/bin/pip install mlx-lm

# Optional: for embedding model support
~/mlx-env/bin/pip install mlx-openai-server
```

### 2. Download an MLX Model

```bash
# Language model
~/mlx-env/bin/huggingface-cli download mlx-community/Qwen2.5-7B-Instruct-4bit

# Embedding model (optional)
~/mlx-env/bin/huggingface-cli download mlx-community/nomic-embed-text-v1.5-bf16
```

### 3. Build & Run

```bash
# Install XcodeGen (one-time)
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Build via command line
xcodebuild -project FlashMLX.xcodeproj -scheme FlashMLX -configuration Release build

# Or open in Xcode and press ⌘R
open FlashMLX.xcodeproj
```

### 4. Use

1. Click the ⚡ icon in the menubar
2. Select a model from the sidebar
3. Adjust config if needed (context length, port)
4. Click **Start** — server runs at `http://localhost:8000/v1`

```bash
# Chat completion (language model)
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "messages": [{"role": "user", "content": "Hello"}]}'

# Embeddings (embedding model)
curl http://localhost:8000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model": "default", "input": "Hello world"}'
```

## Architecture

```
FlashMLX/
├── FlashMLXApp.swift               # @main entry point
├── AppDelegate.swift                # NSStatusBar + Popover + icon state
├── Models/
│   ├── MLXModel.swift               # Local model data struct
│   └── ServerConfig.swift           # Server config (Codable)
├── Services/
│   ├── ModelScanner.swift           # Scan ~/.cache/huggingface/hub/
│   ├── ServerManager.swift          # Process start/stop + logs + memory + health
│   └── ConfigManager.swift          # UserDefaults persistence
├── Views/
│   ├── PopoverView.swift            # Main container (header + sidebar + tabs)
│   ├── ModelListView.swift          # Sidebar model list with badges
│   ├── ConfigView.swift             # Config panel (context, port, type, python)
│   ├── StatusView.swift             # Status cards + quick actions
│   ├── LogView.swift                # Real-time log viewer
│   └── SettingsView.swift           # Launch at login, python verify, reset
├── en.lproj/Localizable.strings     # English
└── zh-Hans.lproj/Localizable.strings # Chinese
```

## Key Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Window mode | Menubar Popover | Launcher doesn't need a full window |
| Process mgmt | Foundation.Process | Swift native subprocess lifecycle control |
| LM Backend | `mlx_lm.server` CLI | Reuse existing inference engine, UI shell only |
| Embedding Backend | `mlx-openai-server` | Dedicated embedding server with `/v1/embeddings` |
| Process safety | PID lock + orphan cleanup | Prevent duplicates, auto-clean crashed processes |
| Model discovery | Scan HF cache | Users' existing models work immediately |
| Config storage | UserDefaults | macOS native, simple, reliable |
| Launch at login | SMAppService | Modern macOS API, no LaunchAgent plist needed |

## Menubar Icon States

| Color | Meaning |
|-------|---------|
| 🟢 Green | Server running |
| 🟠 Orange | Server starting |
| 🔴 Red | Error |
| ⚪ Gray | Stopped |

## License

MIT
