# Android Agent Workbench

Mac-only Codex daemon plus Android Flutter client for managing multiple Codex conversations from a phone.

## Development

### Daemon

- `cd daemon`
- `npm install`
- `npm test`
- `npm run dev`

### App

- `cd app`
- `flutter pub get`
- `flutter test`
- `flutter run`

## Repository Layout

- `daemon/`: Mac-only Node daemon that owns project discovery, conversation state, runs, and realtime updates
- `app/`: Flutter Android client for project switching, conversation switching, and mobile-first conversation control
- `docs/`: product design and implementation plans

## License

MIT
