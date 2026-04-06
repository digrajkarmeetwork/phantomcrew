import 'dart:async' as async_lib;
import 'dart:math';
import 'dart:ui' show Color;
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import '../models/game_state.dart';
import '../models/room_model.dart';
import '../models/station_map.dart';
import '../network/room_manager.dart';
import 'player_component.dart';
import 'station_map_renderer.dart';
import 'effects_system.dart';
import 'lighting_system.dart';

/// World scale: StationMap normalised 0..1 coords × this = pixel coords.
const double kWorldScale = 2048.0;

/// Convert normalised (0..1) position to world pixels.
Vector2 toWorld(double nx, double ny) => Vector2(nx * kWorldScale, ny * kWorldScale);

/// Convert world pixels back to normalised (0..1).
(double, double) toNorm(Vector2 world) => (world.x / kWorldScale, world.y / kWorldScale);

class PhantomGame extends FlameGame with HasCollisionDetection {
  final GameState state;
  final RoomManager roomManager;

  // Components
  late final StationMapRenderer mapRenderer;
  late final EffectsSystem effectsSystem;
  late final LightingSystem lightingSystem;

  // Player components keyed by player ID
  final Map<String, CrewPlayerComponent> playerComponents = {};

  // Bot AI
  async_lib.Timer? _botTick;
  final Map<String, Vector2> _botTargets = {};
  final _rng = Random();

  // Track dead bodies for kill effect detection
  int _prevDeadBodyCount = 0;

  PhantomGame({required this.state, required this.roomManager});

  @override
  Color backgroundColor() => const Color(0xFF040810);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create the world components
    mapRenderer = StationMapRenderer();
    world.add(mapRenderer);

    effectsSystem = EffectsSystem();
    world.add(effectsSystem);

    lightingSystem = LightingSystem(state: state);
    world.add(lightingSystem);

    // Set up camera to follow local player
    camera.viewfinder.anchor = Anchor.center;
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, kWorldScale, kWorldScale),
    );

    // Initial camera position
    final local = state.localPlayer;
    if (local != null) {
      camera.viewfinder.position = toWorld(local.x, local.y);
    }

    // Listen to game state changes
    state.addListener(_onStateChange);

    // Sync initial players
    _syncPlayers();

    // Start bot AI
    _startBotAI();

    // Show HUD overlay
    overlays.add('hud');
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Smoothly follow local player
    final localComp = playerComponents[state.localPlayerId];
    if (localComp != null) {
      final target = localComp.position;
      final current = camera.viewfinder.position;
      camera.viewfinder.position = current + (target - current) * (dt * 6.0).clamp(0.0, 1.0);
    }

    // Update lighting system with player positions
    lightingSystem.updatePlayerPositions(
      playerComponents.values
          .where((c) => c.playerModel.isAlive && !c.playerModel.inVent)
          .map((c) => c.position)
          .toList(),
    );
  }

  void _onStateChange() {
    _syncPlayers();
    _detectKillEffects();
    _updateLightingMode();
  }

  void _syncPlayers() {
    final currentIds = state.players.keys.toSet();
    final componentIds = playerComponents.keys.toSet();

    // Remove departed players
    for (final id in componentIds.difference(currentIds)) {
      final comp = playerComponents.remove(id);
      if (comp != null) {
        world.remove(comp);
      }
    }

    // Add or update players
    for (final entry in state.players.entries) {
      final id = entry.key;
      final player = entry.value;

      if (playerComponents.containsKey(id)) {
        // Update existing
        playerComponents[id]!.syncFromModel(player);
      } else {
        // Create new
        final comp = CrewPlayerComponent(
          playerModel: player,
          isLocalPlayer: id == state.localPlayerId,
        );
        playerComponents[id] = comp;
        world.add(comp);
      }
    }
  }

  void _detectKillEffects() {
    final bodies = state.deadBodies;
    if (bodies.length > _prevDeadBodyCount) {
      for (int i = _prevDeadBodyCount; i < bodies.length; i++) {
        effectsSystem.spawnKillEffect(
          toWorld(bodies[i].x, bodies[i].y),
        );
      }
    }
    _prevDeadBodyCount = bodies.length;
  }

  void _updateLightingMode() {
    final room = state.room;
    lightingSystem.isBlackout =
        room?.activeSabotage == SabotageType.blackoutProtocol;
  }

  // ── Local player input ──────────────────────────────────────────────────

  /// Called by the game screen's gesture detector.
  void moveLocalPlayer(double dx, double dy) {
    final local = state.localPlayer;
    if (local == null || !local.isAlive) return;

    final newX = (local.x + dx).clamp(0.05, 0.95);
    final newY = (local.y + dy).clamp(0.05, 0.95);

    if (!StationMap.isWalkable(newX, newY, sealedZone: state.room?.sealedZone)) return;

    final anim = dx < 0 ? 'walk_left' : (dx > 0 ? 'walk_right' : 'idle');
    state.updatePlayerPosition(state.localPlayerId, newX, newY, anim);
    roomManager.sendMove(newX, newY, anim);
  }

  void stopLocalPlayer() {
    final local = state.localPlayer;
    if (local == null) return;
    state.updatePlayerPosition(state.localPlayerId, local.x, local.y, 'idle');
    roomManager.sendMove(local.x, local.y, 'idle');
  }

  // ── Vent effects ────────────────────────────────────────────────────────

  void spawnVentEffect(double nx, double ny) {
    effectsSystem.spawnVentEffect(toWorld(nx, ny));
  }

  // ── Bot AI ──────────────────────────────────────────────────────────────

  void _startBotAI() {
    final bots = state.players.values.where((p) => p.isBot).toList();
    if (bots.isEmpty) return;

    for (final bot in bots) {
      _botTargets[bot.id] = toWorld(bot.x, bot.y);
    }

    _botTick = async_lib.Timer.periodic(const Duration(milliseconds: 500), (_) {
      _tickBots();
    });
  }

  void _tickBots() {
    for (final botId in _botTargets.keys.toList()) {
      final bot = state.players[botId];
      if (bot == null || !bot.isAlive) continue;

      final target = _botTargets[botId]!;
      final botPos = toWorld(bot.x, bot.y);
      final dist = botPos.distanceTo(target);

      if (dist < 30) {
        // Pick new target
        _botTargets[botId] = toWorld(
          0.1 + _rng.nextDouble() * 0.8,
          0.1 + _rng.nextDouble() * 0.8,
        );

        // Guardian bots: complete tasks
        if (!bot.isPhantom && bot.assignedTasks.isNotEmpty && _rng.nextDouble() < 0.4) {
          final remaining = bot.assignedTasks.where((t) => !bot.completedTasks.contains(t)).toList();
          if (remaining.isNotEmpty) {
            state.completeTask(botId, remaining[_rng.nextInt(remaining.length)]);
          }
        }

        // Phantom bots: attempt kills
        if (bot.isPhantom && _rng.nextDouble() < 0.15) {
          final nearby = state.alivePlayers.where((p) =>
            p.id != botId && !p.isPhantom && p.isAlive &&
            (p.x - bot.x).abs() < 0.08 && (p.y - bot.y).abs() < 0.08
          ).toList();
          if (nearby.isNotEmpty) {
            final victim = nearby[_rng.nextInt(nearby.length)];
            state.markPlayerDead(victim.id, victim.x, victim.y);
          }
        }
      }

      // Move toward target
      final targetN = toNorm(target);
      const step = 0.015;
      var nx = bot.x + (targetN.$1 - bot.x).clamp(-step, step);
      var ny = bot.y + (targetN.$2 - bot.y).clamp(-step, step);
      nx = nx.clamp(0.05, 0.95);
      ny = ny.clamp(0.05, 0.95);

      final anim = (targetN.$1 - bot.x).abs() > 0.01
          ? (targetN.$1 > bot.x ? 'walk_right' : 'walk_left')
          : 'idle';

      state.updatePlayerPosition(botId, nx, ny, anim);
    }
  }

  @override
  void onRemove() {
    state.removeListener(_onStateChange);
    _botTick?.cancel();
    super.onRemove();
  }
}
