# Contributing to FlashMLX

Thanks for your interest in contributing! 🎉

## Development Setup

```bash
# Clone
git clone https://github.com/GuLu9527/FlashMLX.git
cd FlashMLX

# Install XcodeGen
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project FlashMLX.xcodeproj -scheme FlashMLX -configuration Debug build

# Or open in Xcode
open FlashMLX.xcodeproj
```

## Project Structure

- `FlashMLX/Models/` — Data models (MLXModel, ServerConfig)
- `FlashMLX/Services/` — Business logic (ModelScanner, ServerManager, ConfigManager)
- `FlashMLX/Views/` — SwiftUI views
- `FlashMLX/en.lproj/` + `zh-Hans.lproj/` — Localization

## Guidelines

1. **Swift style** — Follow existing code conventions
2. **Localization** — Add new user-visible strings to both `.strings` files
3. **Testing** — Verify the app launches and basic features work before submitting
4. **Commits** — Use clear, descriptive commit messages

## Reporting Issues

Please use the [issue templates](https://github.com/GuLu9527/FlashMLX/issues/new/choose).
