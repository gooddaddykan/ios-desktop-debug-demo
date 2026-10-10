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

## Browser desktop experiment — 2026-10-10

The public simulator app built successfully on standard `macos-15` (Apple Silicon, macOS 15.7.9, Xcode 16.4). The first preflight completed in 42 seconds and returned an RFB/VNC handshake.

A second manual workflow, **Build and browser desktop test**, built the app and started a noVNC browser viewer through a temporary Cloudflare Quick Tunnel. The viewer requires a random 256-bit session path; its complete connection URL is RSA-OAEP encrypted before upload. No Apple account is used.

**Result: interactive desktop access remains unverified.** The operator's cloud browser rejected navigation with `net::ERR_BLOCKED_BY_CLIENT`. The job was canceled immediately afterward. This does not prove that the Mac desktop itself works or fails. macOS also emitted warnings that screen recording/control may require System Settings or MDM permission.

- [Preflight run](https://github.com/gooddaddykan/ios-desktop-debug-demo/actions/runs/38028301240)
- [Browser test run](https://github.com/gooddaddykan/ios-desktop-debug-demo/actions/runs/38028762367)

### Repeating the browser test

Generate your own RSA key pair and replace `debug-session-public.pem` with only the public key. Keep the private key locally. After manually starting the workflow, download `encrypted-desktop-session` and decrypt `connection.enc` using RSA-OAEP with SHA-256. The connection expires when the job ends. Do not publish the private key or the decrypted connection URL.

The session has a 10-minute interaction window and a 20-minute overall job limit. **End session** in the viewer closes it early. No TCC database changes or SIP changes are used.
