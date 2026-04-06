import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import '../models/station_map.dart';
import '../network/relay_client.dart';
import '../network/room_manager.dart';
import '../tasks/task_registry.dart';
import 'meeting_screen.dart';
import 'end_screen.dart';

class GameScreen extends StatefulWidget {
  final GameState state;
  final RelayClient relay;
  final RoomManager roomManager;
  const GameScreen({super.key, required this.state, required this.relay, required this.roomManager});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Local player position (normalised 0..1)
  double _px = 0.5;
  double _py = 0.5;
  String _animation = 'idle';
  Timer? _moveThrottle;
  Timer? _sabotageCheck;
  // Task overlay
  String? _activeTask;

  // Vent state
  String? _currentVentId; // set when player enters a vent

  // Visual effects
  final List<_VisualEffect> _effects = [];
  int _prevDeadBodyCount = 0;

  // Nearby players (for kill / report)
  static const double _interactRadius = 0.08;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChange);
    widget.state.room?.phase = RoomPhase.playing;

    // Sabotage countdown check + cooldown refresh (1s tick)
    _sabotageCheck = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {}); // Refresh HUD for cooldowns and sabotage timer
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChange);
    _moveThrottle?.cancel();
    _sabotageCheck?.cancel();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    final room = widget.state.room;
    if (room?.phase == RoomPhase.ended) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EndScreen(
        state: widget.state,
        relay: widget.relay,
      )));
      return;
    }
    if (widget.state.meetingActive) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MeetingScreen(
        state: widget.state,
        relay: widget.relay,
        roomManager: widget.roomManager,
      ))).then((_) => setState(() {}));
    }

    // Detect new kills → add kill visual effect
    final bodies = widget.state.deadBodies;
    if (bodies.length > _prevDeadBodyCount) {
      for (int i = _prevDeadBodyCount; i < bodies.length; i++) {
        _effects.add(_VisualEffect(
          x: bodies[i].x, y: bodies[i].y,
          type: _EffectType.kill,
          startTime: DateTime.now(),
        ));
      }
    }
    _prevDeadBodyCount = bodies.length;

    // Clean up expired effects
    _effects.removeWhere((e) => e.isExpired);

    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final dx = d.delta.dx / size.width;
    final dy = d.delta.dy / size.height;
    final newX = (_px + dx).clamp(0.05, 0.95);
    final newY = (_py + dy).clamp(0.05, 0.95);

    // Wall collision — only move if destination is walkable (respects sealed zones)
    if (!StationMap.isWalkable(newX, newY, sealedZone: widget.state.room?.sealedZone)) return;

    setState(() {
      _px = newX;
      _py = newY;
      _animation = dx < 0 ? 'walk_left' : 'walk_right';
    });
    _moveThrottle?.cancel();
    _moveThrottle = Timer(const Duration(milliseconds: 50), () {
      widget.roomManager.sendMove(_px, _py, _animation);
    });
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() => _animation = 'idle');
    widget.roomManager.sendMove(_px, _py, 'idle');
  }

  List<PlayerModel> get _nearbyAlive {
    return widget.state.alivePlayers.where((p) {
      if (p.id == widget.state.localPlayerId) return false;
      final dx = p.x - _px;
      final dy = p.y - _py;
      return (dx * dx + dy * dy) < (_interactRadius * _interactRadius);
    }).toList();
  }

  List<DeadBodyModel> get _nearbyBodies {
    return widget.state.deadBodies.where((b) {
      if (b.reported) return false;
      final dx = b.x - _px;
      final dy = b.y - _py;
      return (dx * dx + dy * dy) < (_interactRadius * _interactRadius);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final local = widget.state.localPlayer;
    final isPhantom = widget.state.isPhantom;
    final room = widget.state.room;
    final isBlackout = room?.activeSabotage == SabotageType.blackoutProtocol;

    return Scaffold(
      body: Stack(
        children: [
          // Map background
          GestureDetector(
            onPanUpdate: local?.isAlive == true ? (d) => _onPanUpdate(d, size) : null,
            onPanEnd: local?.isAlive == true ? _onPanEnd : null,
            child: _MapView(
              state: widget.state,
              localX: _px,
              localY: _py,
              localAnimation: _animation,
              isBlackout: isBlackout,
            ),
          ),

          // Blackout overlay
          if (isBlackout)
            _BlackoutOverlay(playerX: _px, playerY: _py),

          // HUD — top
          SafeArea(child: _TopHUD(state: widget.state, roomManager: widget.roomManager)),

          // HUD — bottom action bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              child: _BottomHUD(
                state: widget.state,
                isPhantom: isPhantom,
                localAlive: local?.isAlive ?? false,
                nearbyPlayers: _nearbyAlive,
                nearbyBodies: _nearbyBodies,
                room: room,
                onKill: (victim) => widget.roomManager.sendKill(victim.id, victim.x, victim.y),
                onReport: (body) => widget.roomManager.sendReport(body.victimId),
                onVentEnter: () {
                  final ventId = StationMap.nearestVent(_px, _py);
                  if (ventId != null) {
                    _currentVentId = ventId;
                    widget.roomManager.sendVent('enter', ventId);
                    setState(() {});
                  }
                },
                onVentTravel: (destVentId) {
                  final destPos = StationMap.ventPositions[destVentId];
                  if (destPos != null) {
                    widget.roomManager.sendVent('travel', _currentVentId ?? '', destinationVentId: destVentId, destX: destPos.dx, destY: destPos.dy);
                    _px = destPos.dx;
                    _py = destPos.dy;
                    _currentVentId = destVentId;
                    setState(() {});
                  }
                },
                onVentExit: () {
                  widget.roomManager.sendVent('exit', _currentVentId ?? '');
                  _currentVentId = null;
                  setState(() {});
                },
                currentVentId: _currentVentId,
                localX: _px,
                localY: _py,
                onSabotage: (type) => widget.roomManager.sendSabotage(type),
                onFix: (panel) => widget.roomManager.sendFixSabotage(
                  room?.activeSabotage.name ?? '', panel),
                onMeeting: widget.roomManager.callEmergencyMeeting,
                onTaskOpen: (taskId) => setState(() => _activeTask = taskId),
              ),
            ),
          ),

          // Kill / vent visual effects overlay
          if (_effects.isNotEmpty)
            CustomPaint(
              painter: _EffectPainter(effects: _effects),
              size: MediaQuery.of(context).size,
            ),

          // Connection lost overlay
          if (!widget.state.connected)
            Container(
              color: Colors.black.withAlpha(180),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: PhantomTheme.teal),
                    SizedBox(height: 16),
                    Text('CONNECTION LOST',
                      style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: PhantomTheme.red)),
                    SizedBox(height: 8),
                    Text('Reconnecting...',
                      style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Task overlay
          if (_activeTask != null)
            _TaskOverlay(
              taskId: _activeTask!,
              state: widget.state,
              onComplete: () {
                widget.roomManager.sendTaskComplete(_activeTask!);
                setState(() => _activeTask = null);
              },
              onClose: () => setState(() => _activeTask = null),
            ),
        ],
      ),
    );
  }
}

// ── Map view ─────────────────────────────────────────────────────────────────

class _MapView extends StatelessWidget {
  final GameState state;
  final double localX;
  final double localY;
  final String localAnimation;
  final bool isBlackout;

  const _MapView({
    required this.state,
    required this.localX,
    required this.localY,
    required this.localAnimation,
    required this.isBlackout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Container(
        color: const Color(0xFF080E1C),
        child: Stack(
          children: [
            // Map geometry
            CustomPaint(
              painter: _StationMapPainter(state: state, localX: localX, localY: localY),
              size: Size(w, h),
            ),
            // Other players
            ...state.players.values
              .where((p) => p.id != state.localPlayerId && !p.inVent)
              .map((p) => _PlayerSprite(player: p, canvasW: w, canvasH: h)),
            // Local player (use live position)
            if (state.localPlayer != null)
              _PlayerSprite(
                player: state.localPlayer!,
                overrideX: localX,
                overrideY: localY,
                canvasW: w,
                canvasH: h,
                isLocal: true,
              ),
          ],
        ),
      );
    });
  }
}

class _StationMapPainter extends CustomPainter {
  final GameState state;
  final double localX;
  final double localY;

  _StationMapPainter({
    required this.state,
    required this.localX,
    required this.localY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final roomPaint = Paint()..color = const Color(0xFF111827);
    final wallPaint = Paint()..color = const Color(0xFF1E2D45);
    final tealPaint = Paint()..color = PhantomTheme.teal.withAlpha(40);

    // Rooms
    for (final entry in StationMap.rooms.entries) {
      final r = entry.value;
      final pixelRect = Rect.fromLTWH(r.left * size.width, r.top * size.height, r.width * size.width, r.height * size.height);
      canvas.drawRect(pixelRect, roomPaint);
      canvas.drawRect(pixelRect, wallPaint..style = PaintingStyle.stroke..strokeWidth = 2);

      // Room label
      final tp = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(color: Color(0xFF4A5A7A), fontSize: 9, fontFamily: 'Orbitron'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pixelRect.center.dx - tp.width / 2, pixelRect.top + 6));
    }

    // Corridors
    for (final c in StationMap.corridors) {
      _drawRect(canvas, size, c, roomPaint);
    }

    // Vent grates
    for (final entry in StationMap.ventPositions.entries) {
      final pos = entry.value;
      final cx = pos.dx * size.width;
      final cy = pos.dy * size.height;
      final ventPaint = Paint()..color = PhantomTheme.purple.withAlpha(80);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 10), const Radius.circular(2)),
        ventPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 10), const Radius.circular(2)),
        Paint()..color = PhantomTheme.purple.withAlpha(150)..style = PaintingStyle.stroke..strokeWidth = 1.5,
      );
    }

    // Task zones (glowing dots)
    for (final zone in StationMap.taskZones.values) {
      canvas.drawCircle(
        Offset(zone.dx * size.width, zone.dy * size.height),
        8,
        tealPaint,
      );
      canvas.drawCircle(
        Offset(zone.dx * size.width, zone.dy * size.height),
        5,
        Paint()..color = PhantomTheme.teal,
      );
    }

    // Sabotage fix panel markers (pulsing when active)
    if (state.room?.hasSabotage == true) {
      final sabType = state.room!.activeSabotage.name;
      final panels = StationMap.fixPanels[sabType] ?? {};
      for (final entry in panels.entries) {
        final cx = entry.value.dx * size.width;
        final cy = entry.value.dy * size.height;
        // Outer pulsing ring
        canvas.drawCircle(Offset(cx, cy), 12,
          Paint()..color = PhantomTheme.red.withAlpha(50));
        // Inner marker
        canvas.drawCircle(Offset(cx, cy), 7,
          Paint()..color = PhantomTheme.red.withAlpha(180));
        // Exclamation icon (simple line)
        canvas.drawLine(
          Offset(cx, cy - 4), Offset(cx, cy + 1),
          Paint()..color = Colors.white..strokeWidth = 2..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(Offset(cx, cy + 4), 1.5,
          Paint()..color = Colors.white);
      }
    }

    // Sealed zone overlay (airlock breach)
    final sealedZone = state.room?.sealedZone;
    if (sealedZone != null) {
      final sealedRect = StationMap.rooms[sealedZone];
      if (sealedRect != null) {
        final pixelRect = Rect.fromLTWH(
          sealedRect.left * size.width, sealedRect.top * size.height,
          sealedRect.width * size.width, sealedRect.height * size.height,
        );
        canvas.drawRect(pixelRect, Paint()..color = PhantomTheme.red.withAlpha(40));
        canvas.drawRect(pixelRect, Paint()
          ..color = PhantomTheme.red.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
        // SEALED label
        final tp = TextPainter(
          text: const TextSpan(
            text: 'SEALED',
            style: TextStyle(color: PhantomTheme.red, fontSize: 12, fontFamily: 'Orbitron', fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(pixelRect.center.dx - tp.width / 2, pixelRect.center.dy - tp.height / 2));
      }
    }

    // Dead bodies
    final bodyPaint = Paint()..color = Colors.red.withAlpha(180);
    for (final body in state.deadBodies) {
      if (!body.reported) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(body.x * size.width, body.y * size.height),
            width: 14, height: 8,
          ),
          bodyPaint,
        );
      }
    }

  }

  void _drawRect(Canvas c, Size s, Rect r, Paint p) {
    c.drawRect(Rect.fromLTWH(r.left * s.width, r.top * s.height, r.width * s.width, r.height * s.height), p);
  }

  @override
  bool shouldRepaint(covariant _StationMapPainter old) => true;
}

// ── Player sprite ─────────────────────────────────────────────────────────────

class _PlayerSprite extends StatelessWidget {
  final PlayerModel player;
  final double canvasW;
  final double canvasH;
  final bool isLocal;
  final double? overrideX;
  final double? overrideY;

  const _PlayerSprite({
    required this.player,
    required this.canvasW,
    required this.canvasH,
    this.isLocal = false,
    this.overrideX,
    this.overrideY,
  });

  static const double _spriteW = 44.0;
  static const double _spriteH = 56.0;

  String get _assetPath => player.isGhost
    ? 'assets/images/characters/guardian_ghost.png'
    : 'assets/images/characters/guardian_idle_${player.colorKey}.png';

  @override
  Widget build(BuildContext context) {
    final px = (overrideX ?? player.x) * canvasW;
    final py = (overrideY ?? player.y) * canvasH;

    return Positioned(
      left: px - _spriteW / 2,
      top: py - _spriteH / 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Local player indicator ring
          if (isLocal)
            Container(
              width: _spriteW + 8,
              height: 3,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Opacity(
            opacity: player.isGhost ? 0.55 : 1.0,
            child: Image.asset(
              _assetPath,
              width: _spriteW,
              height: _spriteH,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _FallbackSprite(color: player.color, isGhost: player.isGhost),
            ),
          ),
          Text(
            player.name,
            style: TextStyle(
              color: Colors.white.withAlpha(player.isGhost ? 140 : 220),
              fontSize: 9,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackSprite extends StatelessWidget {
  final Color color;
  final bool isGhost;
  const _FallbackSprite({required this.color, required this.isGhost});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 56,
      decoration: BoxDecoration(
        color: color.withAlpha(isGhost ? 120 : 220),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ── Blackout overlay ──────────────────────────────────────────────────────────

class _BlackoutOverlay extends StatelessWidget {
  final double playerX;
  final double playerY;
  const _BlackoutOverlay({required this.playerX, required this.playerY});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BlackoutPainter(px: playerX, py: playerY),
      size: MediaQuery.of(context).size,
    );
  }
}

class _BlackoutPainter extends CustomPainter {
  final double px;
  final double py;
  _BlackoutPainter({required this.px, required this.py});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = px * size.width;
    final cy = py * size.height;
    final visRadius = size.shortestSide * 0.15;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCenter(center: Offset(cx, cy), width: visRadius * 2, height: visRadius * 2))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black.withAlpha(220));
  }

  @override
  bool shouldRepaint(covariant _BlackoutPainter old) =>
    old.px != px || old.py != py;
}

// ── Top HUD ───────────────────────────────────────────────────────────────────

class _TopHUD extends StatelessWidget {
  final GameState state;
  final RoomManager roomManager;
  const _TopHUD({required this.state, required this.roomManager});

  @override
  Widget build(BuildContext context) {
    final room = state.room;
    final isCommsJammed = room?.activeSabotage == SabotageType.commsJamming;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Task progress (hidden during comms jamming)
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCommsJammed) ...[
                const Text('COMMS OFFLINE', style: TextStyle(
                  color: Colors.orange, fontSize: 10, letterSpacing: 1, fontFamily: 'Orbitron')),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: null, // indeterminate
                    minHeight: 8,
                    backgroundColor: PhantomTheme.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ] else ...[
                const Text('PROTOCOLS', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.taskProgress,
                    minHeight: 8,
                    backgroundColor: PhantomTheme.divider,
                    valueColor: const AlwaysStoppedAnimation<Color>(PhantomTheme.teal),
                  ),
                ),
              ],
            ],
          )),
          const SizedBox(width: 16),
          // Sabotage timer
          if (room?.hasSabotage == true && room?.sabotageTimeRemaining != null)
            _SabotageTimer(remaining: room!.sabotageTimeRemaining!),
        ],
      ),
    );
  }
}

class _SabotageTimer extends StatelessWidget {
  final Duration remaining;
  const _SabotageTimer({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final secs = remaining.inSeconds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PhantomTheme.red.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PhantomTheme.red, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber, color: PhantomTheme.red, size: 14),
          const SizedBox(width: 6),
          Text(
            '${secs}s',
            style: const TextStyle(color: PhantomTheme.red, fontFamily: 'Orbitron', fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Bottom HUD ────────────────────────────────────────────────────────────────

class _BottomHUD extends StatelessWidget {
  final GameState state;
  final bool isPhantom;
  final bool localAlive;
  final List<PlayerModel> nearbyPlayers;
  final List<DeadBodyModel> nearbyBodies;
  final RoomModel? room;
  final void Function(PlayerModel) onKill;
  final void Function(DeadBodyModel) onReport;
  final VoidCallback onVentEnter;
  final void Function(String destVentId) onVentTravel;
  final VoidCallback onVentExit;
  final String? currentVentId;
  final double localX;
  final double localY;
  final void Function(String type) onSabotage;
  final void Function(String panel) onFix;
  final VoidCallback onMeeting;
  final void Function(String taskId) onTaskOpen;

  const _BottomHUD({
    required this.state,
    required this.isPhantom,
    required this.localAlive,
    required this.nearbyPlayers,
    required this.nearbyBodies,
    required this.room,
    required this.onKill,
    required this.onReport,
    required this.onVentEnter,
    required this.onVentTravel,
    required this.onVentExit,
    required this.currentVentId,
    required this.localX,
    required this.localY,
    required this.onSabotage,
    required this.onFix,
    required this.onMeeting,
    required this.onTaskOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (!localAlive) {
      // Ghosts can still complete tasks
      final local = state.localPlayer;
      final pendingTasks = local?.assignedTasks.where((t) => !local.completedTasks.contains(t)).toList() ?? [];
      final nearbyTaskIds = _nearbyTaskIds(pendingTasks);
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: PhantomTheme.panelBg.withAlpha(220),
          border: const Border(top: BorderSide(color: PhantomTheme.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('GHOST', style: TextStyle(color: PhantomTheme.textSecondary, fontFamily: 'Orbitron', fontSize: 10)),
            const SizedBox(height: 8),
            _ActionBtn(
              icon: Icons.build_outlined,
              label: 'TASK',
              color: PhantomTheme.teal.withAlpha(150),
              enabled: nearbyTaskIds.isNotEmpty,
              onTap: nearbyTaskIds.isNotEmpty ? () => _showTaskPicker(context, nearbyTaskIds) : null,
            ),
          ],
        ),
      );
    }

    final local = state.localPlayer;
    final pendingTasks = local?.assignedTasks.where((t) => !local.completedTasks.contains(t)).toList() ?? [];
    final canReport = nearbyBodies.isNotEmpty;
    final isInVent = currentVentId != null;

    // Task proximity gating: only show tasks near the player
    final nearbyTaskIds = _nearbyTaskIds(pendingTasks);

    // Vent proximity: is the player near a vent grate?
    final nearVentId = StationMap.nearestVent(localX, localY);
    final canEnterVent = nearVentId != null && !isInVent && (local?.canVent ?? false);

    // Fix proximity: is the player near a fix panel during active sabotage?
    final nearFixPanel = room?.hasSabotage == true
      ? StationMap.nearestFixPanel(room!.activeSabotage.name, localX, localY)
      : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: PhantomTheme.panelBg.withAlpha(220),
        border: const Border(top: BorderSide(color: PhantomTheme.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // In-vent UI: show destination picker and exit button
          if (isPhantom && isInVent) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...StationMap.ventDestinations(currentVentId!).map((destId) =>
                  _ActionBtn(
                    icon: Icons.subway_outlined,
                    label: StationMap.ventNames[destId] ?? destId,
                    color: PhantomTheme.purple,
                    enabled: true,
                    onTap: () => onVentTravel(destId),
                  ),
                ),
                _ActionBtn(
                  icon: Icons.exit_to_app,
                  label: 'EXIT',
                  color: Colors.white,
                  enabled: true,
                  onTap: onVentExit,
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // GUARDIAN actions
                if (!isPhantom) ...[
                  _ActionBtn(
                    icon: Icons.build_outlined,
                    label: 'TASK',
                    color: PhantomTheme.teal,
                    enabled: nearbyTaskIds.isNotEmpty,
                    onTap: nearbyTaskIds.isNotEmpty ? () => _showTaskPicker(context, nearbyTaskIds) : null,
                  ),
                  if (room?.hasSabotage == true)
                    _ActionBtn(
                      icon: Icons.hardware_outlined,
                      label: 'FIX',
                      color: PhantomTheme.red,
                      enabled: nearFixPanel != null,
                      onTap: nearFixPanel != null ? () => onFix(nearFixPanel) : null,
                    ),
                  _ActionBtn(
                    icon: Icons.campaign_outlined,
                    label: 'MEETING',
                    color: Colors.amber,
                    enabled: (local?.meetingUsesLeft ?? 0) > 0,
                    onTap: onMeeting,
                  ),
                ],
                // PHANTOM actions
                if (isPhantom) ...[
                  _ActionBtn(
                    icon: Icons.close,
                    label: (local?.canKill ?? true)
                      ? 'ELIMINATE'
                      : '${local?.killCooldownRemaining}s',
                    color: PhantomTheme.red,
                    enabled: nearbyPlayers.isNotEmpty && (local?.canKill ?? false),
                    onTap: nearbyPlayers.isNotEmpty && (local?.canKill ?? false)
                      ? () => _showKillPicker(context) : null,
                  ),
                  _ActionBtn(
                    icon: Icons.subway_outlined,
                    label: (local?.canVent ?? true)
                      ? 'PHASE'
                      : '${local?.ventCooldownRemaining}s',
                    color: PhantomTheme.purple,
                    enabled: canEnterVent,
                    onTap: canEnterVent ? onVentEnter : null,
                  ),
                  _ActionBtn(
                    icon: Icons.flash_on_outlined,
                    label: (local?.canSabotage ?? true)
                      ? 'SABOTAGE'
                      : '${local?.sabotageCooldownRemaining}s',
                    color: Colors.orange,
                    enabled: room?.activeSabotage == SabotageType.none && (local?.canSabotage ?? false),
                    onTap: room?.activeSabotage == SabotageType.none && (local?.canSabotage ?? false)
                      ? () => _showSabotagePicker(context) : null,
                  ),
                ],
                // Shared: Report
                _ActionBtn(
                  icon: Icons.warning_outlined,
                  label: 'REPORT',
                  color: Colors.orange,
                  enabled: canReport,
                  onTap: canReport ? () => onReport(nearbyBodies.first) : null,
                ),
              ],
            ),
          ],
          if (!isPhantom && pendingTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tasks: ${local?.completedTasks.length ?? 0}/${local?.assignedTasks.length ?? 0} complete',
                style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  /// Returns task IDs from [pendingTasks] that are near the player's position.
  List<String> _nearbyTaskIds(List<String> pendingTasks) {
    const radius = 0.08;
    return pendingTasks.where((taskId) {
      final zone = StationMap.taskZones[taskId];
      if (zone == null) return false;
      final dx = zone.dx - localX;
      final dy = zone.dy - localY;
      return (dx * dx + dy * dy) < (radius * radius);
    }).toList();
  }

  void _showTaskPicker(BuildContext context, List<String> tasks) {
    if (tasks.length == 1) {
      onTaskOpen(tasks.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: PhantomTheme.panelBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('SELECT TASK', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: PhantomTheme.textPrimary)),
          ),
          ...tasks.map((t) => ListTile(
            leading: const Icon(Icons.build_circle_outlined, color: PhantomTheme.teal),
            title: Text(TaskRegistry.displayName(t), style: const TextStyle(color: PhantomTheme.textPrimary)),
            subtitle: Text(TaskRegistry.zone(t), style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              onTaskOpen(t);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showKillPicker(BuildContext context) {
    if (nearbyPlayers.length == 1) {
      onKill(nearbyPlayers.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: PhantomTheme.panelBg,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('ELIMINATE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: PhantomTheme.red))),
          ...nearbyPlayers.map((p) => ListTile(
            leading: CircleAvatar(backgroundColor: p.color, radius: 12),
            title: Text(p.name, style: const TextStyle(color: PhantomTheme.textPrimary)),
            onTap: () { Navigator.pop(context); onKill(p); },
          )),
        ],
      ),
    );
  }

  void _showSabotagePicker(BuildContext context) {
    final options = [
      ('Reactor Cascade', 'reactorCascade', Icons.thermostat, PhantomTheme.red),
      ('Blackout Protocol', 'blackoutProtocol', Icons.lightbulb_outline, Colors.amber),
      ('Comms Jamming', 'commsJamming', Icons.signal_cellular_off, Colors.orange),
      ('Airlock Breach', 'airlockBreach', Icons.door_front_door_outlined, PhantomTheme.purple),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: PhantomTheme.panelBg,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('SABOTAGE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.orange))),
          ...options.map((opt) => ListTile(
            leading: Icon(opt.$3, color: opt.$4),
            title: Text(opt.$1, style: const TextStyle(color: PhantomTheme.textPrimary)),
            onTap: () { Navigator.pop(context); onSabotage(opt.$2); },
          )),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.35,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(30),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontFamily: 'Orbitron')),
          ],
        ),
      ),
    );
  }
}

// ── Task overlay ──────────────────────────────────────────────────────────────

class _TaskOverlay extends StatelessWidget {
  final String taskId;
  final GameState state;
  final VoidCallback onComplete;
  final VoidCallback onClose;
  const _TaskOverlay({required this.taskId, required this.state, required this.onComplete, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final taskWidget = TaskRegistry.build(taskId, onComplete: onComplete);
    return Material(
      color: Colors.black.withAlpha(200),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(TaskRegistry.displayName(taskId),
                    style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: PhantomTheme.teal)),
                  IconButton(icon: const Icon(Icons.close, color: PhantomTheme.textSecondary), onPressed: onClose),
                ],
              ),
            ),
            Expanded(child: taskWidget),
          ],
        ),
      ),
    );
  }
}

// ── Visual effects ───────────────────────────────────────────────────────────

enum _EffectType { kill, ventGlitch }

class _VisualEffect {
  final double x;
  final double y;
  final _EffectType type;
  final DateTime startTime;

  static const Duration killDuration = Duration(milliseconds: 600);
  static const Duration ventGlitchDuration = Duration(milliseconds: 400);

  _VisualEffect({required this.x, required this.y, required this.type, required this.startTime});

  Duration get duration => type == _EffectType.kill ? killDuration : ventGlitchDuration;
  double get progress => DateTime.now().difference(startTime).inMilliseconds / duration.inMilliseconds;
  bool get isExpired => progress >= 1.0;
}

class _EffectPainter extends CustomPainter {
  final List<_VisualEffect> effects;
  _EffectPainter({required this.effects});

  @override
  void paint(Canvas canvas, Size size) {
    for (final fx in effects) {
      if (fx.isExpired) continue;
      final cx = fx.x * size.width;
      final cy = fx.y * size.height;
      final t = fx.progress.clamp(0.0, 1.0);

      if (fx.type == _EffectType.kill) {
        // Expanding dark-red circle that fades out
        final radius = 10 + t * 40;
        final alpha = ((1.0 - t) * 180).toInt();
        canvas.drawCircle(
          Offset(cx, cy), radius,
          Paint()..color = Color.fromARGB(alpha, 200, 30, 30),
        );
        // Inner dark pulse
        canvas.drawCircle(
          Offset(cx, cy), radius * 0.5,
          Paint()..color = Color.fromARGB((alpha * 0.6).toInt(), 80, 0, 60),
        );
      } else if (fx.type == _EffectType.ventGlitch) {
        // Horizontal scan-line glitch effect
        final alpha = ((1.0 - t) * 150).toInt();
        for (int i = -3; i <= 3; i++) {
          final lineY = cy + i * 4;
          canvas.drawRect(
            Rect.fromCenter(center: Offset(cx + (i % 2 == 0 ? 3 : -3), lineY), width: 20, height: 2),
            Paint()..color = Color.fromARGB(alpha, 123, 47, 190),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EffectPainter old) => true;
}
