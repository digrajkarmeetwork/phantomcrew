# PHANTOM CREW — Claude Context Document

> This file gives Claude full project context. Read this before doing any work on this codebase.

---

## 1. What Is This Project?

**Phantom Crew** is a mobile-first social deduction game for **iOS and Android**, supporting **up to 8 players** simultaneously over the internet. It is a complete remake of the original "BetweenUs" prototype — rebranded, redesigned, with an original backstory, original AI-generated art assets, and rebuilt for mobile devices.

The original BetweenUs was a Java/LibGDX desktop game that used copied Among Us sprites and had no original identity. This project replaces everything: the name, the art, the story, and the platform target.

---

## 2. Game Name & Branding

| Field | Value |
|---|---|
| **Game Title** | PHANTOM CREW |
| **Tagline** | "Trust no one. The phantom is already among you." |
| **Genre** | Social Deduction / Multiplayer |
| **Players** | 2–8 (optimised for 8) |
| **Platforms** | Android (primary), iOS |
| **Target Age** | 13+ |
| **Tone** | Sci-fi thriller, tense, atmospheric |

---

## 3. Original Game Summary (BetweenUs — What We're Replacing)

The original codebase is a **Java + LibGDX** desktop game:
- Inspired directly by Among Us, copying its visual identity (Polus map, astronaut character sprites from spriters-resource.com)
- WebSocket relay server (Node.js) for internet multiplayer, UDP for LAN
- 4 tasks: Admin (swipe card), Comms (reset modem), Electrical (wire matching), Reactor (number sequence)
- Imposters can vent, sabotage lights, trigger reactor meltdown
- 50+ hat cosmetics
- Emergency meetings with 60-second voting timer
- Desktop only (LWJGL), no mobile support

**Everything from this prototype must be replaced.** The only reusable elements are the game-logic concepts (roles, tasks, voting, meetings).

---

## 4. Phantom Crew — Backstory & Lore

### Setting

**Year 2157.** Humanity has expanded beyond the solar system, establishing the **Celestial Mining Collective (CMC)** — a fleet of deep-space stations extracting rare quantum minerals from asteroid belts near distant stars.

You are crew aboard **CMC Horizon Station**, a cutting-edge orbital platform positioned near the **Rift** — a mysterious quantum anomaly that warps space and time. The station is humanity's most valuable asset and most dangerous posting.

### The Threat

During an unexpected pulse from the Rift, something got in.

A parasitic alien entity — classified **PHANTOM** — can **perfectly replicate a human host**, absorbing their memories and mimicking their behaviour. Once a crew member is infected, they become a **Phantom Agent**: indistinguishable from the original crew member, but working to sabotage the station and open the Rift fully, allowing the Phantom swarm to pour through and consume humanity.

### The Roles

**GUARDIANS** (innocent crew members)
- Crew members who are not infected
- Must complete **Station Protocols** (tasks) to stabilise the quantum core
- Can call **Emergency Assemblies** to debate and vote out suspects
- Win by: completing all protocols OR eliminating all Phantom Agents

**PHANTOM AGENTS** (imposters)
- Infected crew members serving the alien hive
- Can **phase-shift** through maintenance conduits (venting mechanic)
- Can **sabotage** station systems: Reactor Cascade, Blackout Protocol, Comms Jamming
- Can **neutralise** Guardians (kill mechanic)
- Win by: outnumbering Guardians OR completing the Cascade Sabotage before Guardians can respond

### Flavour Text on Ejection
When a player is voted off: *"[PlayerName] was jettisoned into the Rift. They were [a Guardian / a Phantom Agent]."*

---

## 5. Characters

### Guardian (Crew Member)
- Humanoid crew member in a space suit
- Sleek, futuristic design — NOT the round astronaut from Among Us
- Visor helmet that glows softly (different colours per player)
- Slim, bipedal silhouette
- Has a tool belt and equipment harness
- When dead: becomes a translucent blue energy ghost (holographic afterimage)

### Phantom Agent (Imposter)
- Looks identical to a Guardian — no visible tell until they act
- When using phase-shift (vent): body momentarily flickers/glitches
- When killing: a brief dark pulse radiates outward

### Player Colours (8 slots)
Cyan, Red, Orange, Purple, Green, Pink, White, Yellow

### Cosmetics (replacing hats)
- **Visors**: different helmet visor colours and patterns
- **Emblems**: faction/rank badges on the chest
- **Glows**: different suit glow colours

---

## 6. Game Map

### CMC Horizon Station
Replace the Polus map with an original space station layout:

| Zone | Description | Tasks Available |
|---|---|---|
| **Command Bridge** | Main control room, front of station | Navigation Calibration, ID Verification |
| **Engineering Bay** | Engine room, lower level | Reactor Alignment, Power Routing |
| **Research Lab** | Central hub with quantum equipment | Sample Analysis, Data Upload |
| **Life Support** | Oxygen and atmosphere control | Air Scrubber Maintenance, Filter Replace |
| **Comms Array** | Communication tower, upper level | Signal Boost, Satellite Align |
| **Maintenance Tunnels** | Interconnecting passages (vent network) | — (Phantoms only) |
| **Airlock** | Exterior access, danger zone | — |

### Phase-Shift Conduits (Vents)
Phantom Agents can travel through a network of maintenance conduits:
- Engineering Bay ↔ Maintenance Tunnels ↔ Life Support
- Command Bridge ↔ Comms Array
- Research Lab is isolated (no vent access — high-value tactical zone)

---

## 7. Tasks (Station Protocols)

Each Guardian is assigned 3 random tasks from:

| Task | Zone | Mechanic |
|---|---|---|
| **Navigation Calibration** | Command Bridge | Rotate dials to align a star map |
| **ID Verification** | Command Bridge | Scan a holographic ID badge (swipe gesture) |
| **Reactor Alignment** | Engineering Bay | Match energy frequency sliders |
| **Power Routing** | Engineering Bay | Connect coloured power conduits (wire puzzle) |
| **Sample Analysis** | Research Lab | Wait for analysis bar to fill, then submit |
| **Data Upload** | Research Lab | Hold button until upload completes |
| **Air Scrubber Maintenance** | Life Support | Remove and replace filter panels |
| **Filter Replace** | Life Support | Sequence-based filter insertion |
| **Signal Boost** | Comms Array | Tune frequency dials to target range |
| **Satellite Align** | Comms Array | Tap sequence to align satellite dishes |

---

## 8. Sabotages (Phantom Abilities)

| Sabotage | Effect | Fix Method |
|---|---|---|
| **Reactor Cascade** | 45-second countdown to Phantom win; ALL Guardians must fix | Two Guardians simultaneously hold panels in Engineering Bay |
| **Blackout Protocol** | Station lights go dark; Guardians have very limited vision | Two Guardians restore power at separate breaker boxes |
| **Comms Jamming** | Task progress bars hidden; Guardians can't see completed tasks | One Guardian fixes the Comms Array terminal |
| **Airlock Breach** | One zone is sealed off, blocking movement | One Guardian at Command Bridge reopens it |

---

## 9. Technical Architecture

### Target Stack

| Layer | Technology | Rationale |
|---|---|---|
| **Game Engine** | Flutter + Flame 1.x | Single codebase → iOS + Android; Dart; mature 2D game framework |
| **Backend / Relay** | Node.js + WebSocket (existing relay-server/) | Already working; extend for 8-player capacity |
| **Real-time Sync** | WebSocket JSON protocol (extend existing) | Low latency; no third-party dependency |
| **Asset Pipeline** | AI-generated (Stability AI / DALL-E / Replicate) | Original assets; see Section 11 |
| **State Management** | Riverpod (Flutter) | Clean reactive state for game entities |
| **Local Storage** | shared_preferences | Player name, cosmetics, settings persistence |
| **Audio** | flame_audio | In-game SFX and ambient music |

### Project Structure (Target)
```
phantom-crew/
├── CLAUDE.md                    ← This file
├── lib/
│   ├── main.dart                ← App entry point
│   ├── game/
│   │   ├── phantom_crew_game.dart  ← Root Flame game class
│   │   ├── components/          ← Flame components
│   │   │   ├── player.dart
│   │   │   ├── phantom_agent.dart
│   │   │   ├── station_map.dart
│   │   │   ├── vent.dart
│   │   │   └── task_zone.dart
│   │   ├── screens/
│   │   │   ├── main_menu.dart
│   │   │   ├── lobby.dart
│   │   │   ├── game_screen.dart
│   │   │   ├── meeting.dart
│   │   │   ├── role_reveal.dart
│   │   │   └── end_game.dart
│   │   ├── tasks/
│   │   │   ├── navigation_calibration.dart
│   │   │   ├── reactor_alignment.dart
│   │   │   ├── power_routing.dart
│   │   │   └── ... (one file per task)
│   │   ├── network/
│   │   │   ├── relay_client.dart   ← WebSocket relay client
│   │   │   ├── game_protocol.dart  ← Message serialisation
│   │   │   └── room_manager.dart
│   │   └── models/
│   │       ├── player_model.dart
│   │       ├── room_model.dart
│   │       └── game_state.dart
│   └── ui/
│       ├── widgets/
│       └── theme.dart
├── assets/
│   ├── images/
│   │   ├── characters/          ← Guardian sprites (all 8 colours)
│   │   ├── phantoms/            ← Phantom Agent sprites
│   │   ├── map/                 ← Station map tiles and background
│   │   ├── tasks/               ← Task UI imagery
│   │   ├── ui/                  ← Buttons, panels, HUD elements
│   │   ├── cosmetics/           ← Visor/emblem/glow options
│   │   └── fx/                  ← Effects (kill flash, vent glitch, etc.)
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── fonts/
├── relay-server/                ← Existing Node.js relay (extend, don't replace)
│   ├── server.js
│   └── package.json
├── android/
├── ios/
├── pubspec.yaml
└── scripts/
    └── generate_assets.py       ← AI asset generation script
```

### Multiplayer Protocol (Extend Existing Relay)

The existing relay-server works well. Extend the JSON protocol:

```json
// Player position update
{"type": "player_move", "room": "...", "id": "...", "x": 0.5, "y": 0.3, "dir": "left", "anim": "walk"}

// Kill event
{"type": "kill", "room": "...", "killer": "...", "victim": "...", "x": 0.4, "y": 0.2}

// Vent action
{"type": "vent", "room": "...", "player": "...", "action": "enter|exit|travel", "vent_id": "eng_1"}

// Sabotage
{"type": "sabotage", "room": "...", "player": "...", "sabotage": "reactor|blackout|comms|airlock"}

// Emergency meeting
{"type": "meeting", "room": "...", "caller": "...", "reason": "button|body", "body_id": "..."}

// Vote
{"type": "vote", "room": "...", "voter": "...", "target": "...|skip"}

// Task complete
{"type": "task_done", "room": "...", "player": "...", "task": "reactor_alignment", "progress": 0.6}
```

### 8-Player Support
The existing relay-server already handles dynamic room sizes. Ensure:
- Room max players set to 8 in room creation
- Role distribution: with 8 players → 1-2 Phantoms (configurable by host: 1 for 4-5 players, 2 for 6-8)
- Task count scales: each player gets 3 tasks; 8 players = 24 total task completions needed

---

## 10. Screen Flow

```
Splash Screen → Main Menu
                    ├── Create Room → Lobby (host) → Role Reveal → Game → End Screen → Main Menu
                    ├── Join Room   → Lobby (guest) → Role Reveal → Game → End Screen → Main Menu
                    └── Settings
```

**Game → Meeting** is an overlay on the Game screen (not a separate screen route).

---

## 11. AI Asset Generation

All game art must be **AI-generated** using one or more of these tools:

| Tool | Use Case | API |
|---|---|---|
| **Stability AI (SDXL)** | Characters, map tiles, backgrounds | `https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image` |
| **DALL-E 3 (OpenAI)** | UI elements, concept art, icons | `https://api.openai.com/v1/images/generations` |
| **Replicate** | Sprite sheets, pixel art variants | `https://api.replicate.com/v1/predictions` |

### Required Assets Checklist
Use `/generate-assets` skill to run the generation pipeline.

#### Characters (PNG sprite sheets)
- [ ] Guardian idle (all 8 colours) — 64×64px per frame, 4 frames
- [ ] Guardian walk left/right (all 8 colours) — 64×64px, 4 frames
- [ ] Guardian death animation — 64×64px, 6 frames
- [ ] Guardian ghost/dead state (all 8 colours) — translucent blue, 64×64px
- [ ] Phantom vent-enter animation — 64×64px, 4 frames
- [ ] Phantom kill animation — 64×64px, 4 frames

#### Map Assets (PNG)
- [ ] CMC Horizon Station full map (2048×2048px)
- [ ] Room tiles: floor, wall, doorway, equipment (128×128px each)
- [ ] Vent grate sprite (closed/open states)
- [ ] Task station indicators (glowing console icons)

#### UI Elements (PNG)
- [ ] Main menu background — space panorama (1080×1920px)
- [ ] HUD panel (bottom bar, semi-transparent)
- [ ] Kill button icon
- [ ] Report button icon
- [ ] Vent button icon (phase-shift)
- [ ] Sabotage button icon
- [ ] Emergency meeting button
- [ ] Task interaction button
- [ ] Vote card UI
- [ ] Meeting room background overlay

#### Role Reveal Screens (PNG, 1080×1920px)
- [ ] Guardian reveal screen — blue/green tones, heroic
- [ ] Phantom Agent reveal screen — dark/red tones, ominous

#### Win/Lose Screens (PNG, 1080×1920px)
- [ ] Guardians win screen
- [ ] Phantoms win screen

#### Task UI (PNG)
- [ ] Navigation calibration background
- [ ] Reactor alignment background
- [ ] Power routing background (with coloured conduit art)
- [ ] Signal boost background
- [ ] ID verification background

#### Cosmetics
- [ ] 8 visor style options (icon, 64×64px each)
- [ ] 8 emblem options (icon, 64×64px each)

### AI Prompt Templates
Store prompts in `scripts/asset_prompts.json`. Example style reference:

```
Style: "sci-fi mobile game sprite, clean vector art, dark space station aesthetic, 
teal and dark blue colour palette, high contrast, transparent background"

Guardian character: "humanoid space crew member, sleek futuristic spacesuit with glowing visor, 
bipedal silhouette, tool belt, [COLOR] suit colour, no helmet bubble, clean line art, 
game sprite, transparent background, front-facing"
```

---

## 12. Development Workflow

### Branches
- **`master`** — stable, do not push breaking changes
- **`claude/game-redesign-original-assets-1FjHj`** — active development branch (current)

### Always Do Before Pushing
1. Run `flutter analyze` — zero errors
2. Run `flutter test` — all pass
3. Check that relay-server still starts: `cd relay-server && node server.js`

### Key Commands
```bash
# Flutter
flutter pub get             # Install deps
flutter run                 # Run on connected device/emulator
flutter build apk --release # Build Android APK
flutter build ios --release # Build iOS (requires macOS + Xcode)
flutter test               # Run tests
flutter analyze            # Static analysis

# Relay server
cd relay-server && npm install && npm start

# Asset generation (requires API keys in .env)
python3 scripts/generate_assets.py --category characters
python3 scripts/generate_assets.py --category map
python3 scripts/generate_assets.py --all
```

### Environment Variables (`.env` — never commit)
```
STABILITY_API_KEY=sk-...
OPENAI_API_KEY=sk-...
REPLICATE_API_TOKEN=r8_...
```

---

## 13. Design Principles

1. **Mobile-first**: All UI elements must be touch-friendly (minimum 44×44pt tap targets). No keyboard shortcuts.
2. **Original IP**: Zero borrowed assets. Every pixel must be AI-generated or custom. No Among Us, no copyrighted material.
3. **8-player parity**: All features must work identically whether there are 2 or 8 players.
4. **Low latency feels**: Position updates should fire at 20Hz. Game state events (kills, vents, sabotages) must be immediate.
5. **Accessible colours**: Player colour palette must be distinguishable by colour-blind users. Use both colour and shape/pattern indicators.
6. **Offline-resilient**: If the relay drops, show a reconnection UI — do not silently fail.

---

## 14. Out of Scope (v1.0)

- Voice chat (text chat only in meetings)
- Single-player vs AI
- Account system / leaderboards (guest play only in v1)
- PC/desktop build (mobile only for v1)
- More than 8 players
- Custom map editor

---

## 15. Existing Codebase Reference

The Java/LibGDX codebase in this repo is a **reference only** for game logic. Do not build on top of it for the mobile remake — create the Flutter project fresh. Useful reference files:

| Java File | What to Learn From It |
|---|---|
| `core/src/com/server/Server.java` | Role assignment algorithm, win condition logic |
| `core/src/com/server/Room.java` | Room state management |
| `core/src/com/mmog/players/Player.java` | Player state fields |
| `core/src/com/mmog/screens/GameScreen.java` | Game loop and rendering approach |
| `relay-server/server.js` | **Reuse this directly** — extend, don't rewrite |

---

## 16. Skills Available

Use these project slash commands:

| Command | Purpose |
|---|---|
| `/generate-assets` | Run AI image generation for specified asset categories |
| `/build-mobile` | Build and validate the Flutter mobile app |
| `/add-task` | Scaffold a new in-game task mini-game |
| `/design-review` | Review current implementation against design doc |

---

*Last updated: 2026-04-06 | Branch: claude/game-redesign-original-assets-1FjHj*
