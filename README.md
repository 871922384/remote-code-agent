# Android Agent Workbench

Mac-only Codex daemon plus Android Flutter client for managing multiple Codex conversations from a phone.

## Development

### Daemon

- `cd daemon`
- `npm install`
- `npm test`
- `npm run dev`

Optional remote auth:

- `DAEMON_AUTH_TOKEN=your-shared-secret node src/index.js`
- Or set `DAEMON_AUTH_TOKEN` before launching the macOS companion app
- Mobile clients must enter the same token in Connection settings

### App

- `cd app`
- `flutter pub get`
- `flutter test`
- `flutter run`

### macOS Finder Build

- `npm run build:macos:companion`
- Output: `app/build/macos/Build/Products/Release/agent_workbench.app`
- Double-click the `.app` in Finder to open the daemon companion shell.

The release macOS app bundles both the daemon and a Node runtime inside
`Contents/Resources`.

Runtime data belongs under:

- `~/Library/Application Support/agent_workbench/`

Runtime logs belong under:

- `~/Library/Logs/agent_workbench/`

If `flutter build macos` stops in `pod install` with `certificate verify failed`,
the blocker is your local CocoaPods/Ruby certificate chain or proxy configuration,
not the app code. Fix the trust store or retry with direct access to
`https://cdn.cocoapods.org/`.

The bundled build script exports Homebrew OpenSSL cert paths automatically when
available:

- `SSL_CERT_FILE=/opt/homebrew/etc/openssl@3/cert.pem`
- `SSL_CERT_DIR=/opt/homebrew/etc/openssl@3/certs`

## Repository Layout

- `daemon/`: Mac-only Node daemon that owns project discovery, conversation state, runs, and realtime updates
- `app/`: Flutter Android client for project switching, conversation switching, and mobile-first conversation control
- `docs/`: product design and implementation plans

## License

MIT
