# PHANTOM CREW

> *Trust no one. The phantom is already among you.*

A sci-fi social deduction game for up to 8 players, playable in the browser on any device.

## Play Now

**[Play Phantom Crew](https://digrajkarmeetwork.github.io/phantomcrew/)**

Open the link on your phone or desktop browser. On mobile, tap "Add to Home Screen" to install it as a PWA for a full-screen app experience.

## About

Phantom Crew is set aboard **CMC Horizon Station** in the year 2157. Parasitic alien entities — **Phantoms** — have infiltrated the crew. Guardians must complete station protocols and vote out the impostors before it's too late.

- **2–8 players** over the internet
- **10 unique tasks** across 5 station zones
- **Emergency assemblies** with chat and voting
- **Phantom abilities**: phase-shift (vent), sabotage, neutralise
- **PWA**: installable on iOS and Android — no app store needed

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter Web (Dart) |
| Renderer | CanvasKit |
| Backend | Node.js WebSocket relay server |
| Hosting | GitHub Pages |
| Assets | AI-generated (Stability AI) |

## Development

```bash
# Flutter app
cd phantom-crew
flutter pub get
flutter run -d chrome

# Relay server
cd relay-server
npm install
npm start
```

### Build for deployment

```bash
cd phantom-crew
flutter build web --release --web-renderer canvaskit --base-href "/phantomcrew/"
```

The output lands in `phantom-crew/build/web/` and is auto-deployed to GitHub Pages on push to `master`.

## Relay Server

The relay server handles real-time multiplayer communication. Players connect via WebSocket through the relay — no port forwarding needed.

To host your own:

```bash
cd relay-server
npm install
npm start
```

Or deploy to Railway/Render/Fly.io for a public instance.

## Project Structure

```
phantomcrew/
├── phantom-crew/          # Flutter web app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── game/
│   │   │   ├── screens/   # Menu, lobby, game, meeting, end
│   │   │   ├── tasks/     # 10 mini-game tasks
│   │   │   ├── models/    # Game state, player, room, map
│   │   │   ├── network/   # Relay client, protocol, room manager
│   │   │   └── audio/     # Audio manager
│   │   └── ui/            # Theme and widgets
│   ├── assets/            # AI-generated art, audio, fonts
│   ├── web/               # PWA shell (index.html, manifest.json)
│   └── test/              # Unit tests
├── relay-server/          # Node.js WebSocket relay
├── scripts/               # Asset generation scripts
└── .github/workflows/     # CI/CD (web deploy, relay package)
```
