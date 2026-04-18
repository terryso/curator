## Project: Curator

AI-powered macOS photo management agent. Built on [OpenAgentSDKSwift](https://github.com/terryso/open-agent-sdk-swift).

## Architecture

- **Language:** Swift (macOS 15+, SwiftUI + AppKit)
- **SDK Dependency:** OpenAgentSDKSwift via Swift Package Manager
- **Distribution:** DMG (notarized, not App Store)

## Project Conventions

- This project uses a BMAD story pipeline workflow. Follow the 5-step pipeline: story creation -> ATDD tests -> development -> code review -> coverage trace.
- Run the full test suite after making changes and report the total count.

## UI Design Rules

- When implementing UI features or story tasks involving macOS interface, always invoke /macos-design-guidelines first to load relevant HIG context.

## Swift Conventions

- Avoid naming types `Task` — it conflicts with Swift Concurrency's `Task`. Use a project-specific prefix or alternative name.
- When SourceKit reports large numbers of compilation errors, verify via `swift build` or `xcodebuild` before attempting fixes.
