# iOS Desktop Debug Demo

A small public SwiftUI counter app for testing iOS simulator builds and temporary desktop debugging on GitHub-hosted macOS runners.

## Run

Run **Build and desktop preflight** from Actions. The job uses the standard `macos-15` runner and has a hard 20-minute limit. It builds this demo without signing, then checks whether macOS Screen Sharing can start and accept a local VNC handshake. It does not sign into Apple, load private projects, or publish credentials.

The initial preflight intentionally ends after diagnostics. A listening VNC port alone does not prove that remote viewing or keyboard/mouse control works.

## Local build

Install Xcode and XcodeGen, then run:

```sh
xcodegen generate
xcodebuild -project DesktopDebugDemo.xcodeproj -scheme DesktopDebugDemo -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub's public-repository allowance applies to development and testing of the software in this repository. It is not an unlimited general-purpose Mac desktop service.
