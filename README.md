# Curator

[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue)](https://developer.apple.com/macos/)
[![CI](https://github.com/terryso/curator/actions/workflows/ci.yml/badge.svg)](https://github.com/terryso/curator/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/terryso/251b737676c9527b3193aa9cea49ff86/raw/coverage.json)](https://github.com/terryso/curator/actions)
[![BMAD](https://bmad-badge.vercel.app/terryso/curator.svg)](https://github.com/bmad-code-org/BMAD-METHOD)

AI-powered macOS photo management agent built on [OpenAgentSDKSwift](https://github.com/terryso/open-agent-sdk-swift).

## Overview

Curator is a native macOS application that uses AI agents to help you organize, rename, deduplicate, and manage your photo library through natural language commands.

## Features

- Natural language photo management via AI agents
- Smart duplicate detection with perceptual hashing
- AI-powered photo renaming based on content analysis
- Progressive permission model for safe operations
- Multi-provider LLM support with cost tracking
- Batch operations with undo/rollback

## Tech Stack

- **Language:** Swift 6 (strict concurrency)
- **UI:** SwiftUI + AppKit
- **SDK:** [OpenAgentSDKSwift](https://github.com/terryso/open-agent-sdk-swift)
- **Distribution:** DMG (notarized, not App Store)
- **Auto-update:** [Sparkle](https://github.com/sparkle-project/Sparkle)

## Development

```bash
# Generate Xcode project
brew install xcodegen
xcodegen generate

# Build
xcodebuild build -project Curator.xcodeproj -scheme Curator \
  -destination 'platform=macOS,arch=arm64'

# Test
xcodebuild test -project Curator.xcodeproj -scheme Curator \
  -destination 'platform=macOS,arch=arm64' \
  -enableCodeCoverage YES \
  -only-testing:CuratorTests
```

## Architecture

Curator follows a layered architecture:

```
Presentation (SwiftUI) → Application (DI, ViewModels) → Domain (Models, Protocols) → Infrastructure (PhotoKit, LLM)
```

See [architecture.md](_bmad-output/planning-artifacts/architecture.md) for detailed design decisions.
