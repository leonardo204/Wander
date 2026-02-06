# Wander Agent Guidelines

This document provides instructions for AI agents working on the Wander iOS repository.

## Project Overview
Wander is an iOS 17+ application built with SwiftUI and SwiftData. It focuses on privacy-first (on-device) travel timeline generation and AI storytelling (BYOK).

**Tech Stack:**
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Database:** SwiftData (Schema: `TravelRecord`, `TravelDay`, `Place`, `PhotoItem`, etc.)
- **Project Generation:** XcodeGen (`project.yml`)
- **Dependencies:** Swift Package Manager (managed via `project.yml`)

---

## Build & Test Commands

### 1. Project Generation (CRITICAL)
Always regenerate the Xcode project file if `project.yml` or file structure changes.
```bash
xcodegen generate
```

### 2. Build Application
Build for iOS Simulator (iPhone 15 Pro by default).
```bash
xcodebuild build \
  -scheme Wander \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -quiet
```

### 3. Run Tests
Run all tests.
```bash
xcodebuild test \
  -scheme Wander \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -quiet
```

### 4. Run Single Test Class/Case
To run a specific test class:
```bash
xcodebuild test \
  -scheme Wander \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:WanderTests/SomeTestClass
```

---

## Code Style & Conventions

### 1. Language & formatting
- **Swift Version:** 5.9+ (Use `if let x` shorthand, macros where appropriate).
- **Indentation:** 4 spaces.
- **Comments:** Write comments in **Korean** (Hangul).
  - Example: `// P2P 공유 관련 로직`
- **Logging:** Use `os.Logger` subsystem: `com.zerolive.wander`.
  - Do not use `print()`.
  ```swift
  private let logger = Logger(subsystem: "com.zerolive.wander", category: "CategoryName")
  logger.info("🚀 [Category] Message")
  ```

### 2. Architecture (MVVM)
- **Views:** `src/Views/{FeatureName}/`
- **ViewModels:** `src/ViewModels/` (Use `@Observable` macro if targeting iOS 17+ only, otherwise `ObservableObject`).
- **Models:** `src/Models/` (SwiftData `@Model`).
- **Services:** `src/Services/` (Business logic, API calls).

### 3. SwiftData Best Practices
- Initialize `ModelContainer` in `WanderApp.swift`.
- Use `@Query` in Views for automatic updates.
- Perform heavy data operations in background contexts using `ModelActor` if possible, or careful `@MainActor` usage.

### 4. UI/UX Guidelines
- **Theme:** Light mode fixed (`.preferredColorScheme(.light)`).
- **Components:** Reuse components from `src/Views/Shared/` where possible.
- **Assets:** Use system symbols (SF Symbols) or assets defined in `Resources/Assets.xcassets`.

### 5. File Structure
Keep the `project.yml` sources list updated if adding new top-level folders.
```
src/
├── WanderApp.swift
├── Models/         # Data models (@Model)
├── Views/          # SwiftUI Views organized by feature
│   ├── Home/
│   ├── Analysis/
│   └── Shared/
├── ViewModels/     # View logic
├── Services/       # Data processing, AI integration
└── Resources/      # Assets, Info.plist
```

### 6. Common Patterns
- **Async/Await:** Prefer structured concurrency (`Task`, `async/await`) over completion handlers.
- **Error Handling:** Use `do-catch` blocks and log errors using `logger.error`.
- **Extensions:** Place utility extensions in `src/Core/Extensions`.

## Cursor/Copilot Rules
- If editing `project.yml`, run `xcodegen generate` immediately after.
- When creating new Views, ensure they have a corresponding Preview.
