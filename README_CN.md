# Curator

[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue)](https://developer.apple.com/macos/)
[![CI](https://github.com/terryso/curator/actions/workflows/ci.yml/badge.svg)](https://github.com/terryso/curator/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/terryso/251b737676c9527b3193aa9cea49ff86/raw/coverage.json)](https://github.com/terryso/curator/actions)
[![BMAD](https://bmad-badge.vercel.app/terryso/curator.svg)](https://github.com/bmad-code-org/BMAD-METHOD)

基于 [OpenAgentSDKSwift](https://github.com/terryso/open-agent-sdk-swift) 的 AI 驱动 macOS 照片管理代理。

[English](./README.md)

## 概述

Curator 是一款原生 macOS 应用，通过 AI 代理帮助你用自然语言命令来整理、重命名、去重和管理照片图库。

## 功能特性

- 通过 AI 代理实现自然语言照片管理
- 基于感知哈希的智能去重
- 基于内容分析的 AI 智能重命名
- 渐进式权限模型保障操作安全
- 多 LLM 供应商支持与成本追踪
- 批量操作，支持撤销/回滚

## 技术栈

- **语言：** Swift 6（严格并发）
- **界面：** SwiftUI + AppKit
- **SDK：** [OpenAgentSDKSwift](https://github.com/terryso/open-agent-sdk-swift)
- **分发：** DMG（公证，非 App Store）
- **自动更新：** [Sparkle](https://github.com/sparkle-project/Sparkle)

## 开发

```bash
# 生成 Xcode 项目
brew install xcodegen
xcodegen generate

# 构建
xcodebuild build -project Curator.xcodeproj -scheme Curator \
  -destination 'platform=macOS,arch=arm64'

# 测试
xcodebuild test -project Curator.xcodeproj -scheme Curator \
  -destination 'platform=macOS,arch=arm64' \
  -enableCodeCoverage YES \
  -only-testing:CuratorTests
```

## 架构

Curator 采用分层架构：

```
展示层 (SwiftUI) → 应用层 (DI, ViewModels) → 领域层 (Models, Protocols) → 基础设施层 (PhotoKit, LLM)
```

详细设计决策参见 [architecture.md](_bmad-output/planning-artifacts/architecture.md)。
