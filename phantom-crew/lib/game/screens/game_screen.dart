import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
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

  // Nearby players (for kill / report)
  static const double _interactRadius = 0.08;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChange);
    widget.state.room?.phase = RoomPhase.playing;

    // Sabotage countdown check
    _sabotageCheck = Timer.periodic(const Duration(seconds: 1), (_) {
      final room = widget.state.room;
      if (room == null) return;
      final rem = room.sabotageTimeRemaining;
      if (rem != null && rem == Duration.zero && room.activeSabotage == SabotageType.reactorCascade) {
        // Phantom wins via cascade timeout — handled server side but show locally
        if (mounted) setState(() {});
      }
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
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final dx = d.delta.dx / size.width;
    final dy = d.delta.dy / size.height;
    setState(() {
      _px = (_px + dx).clamp(0.05, 0.95);
      _py = (_py + dy).clamp(0.05, 0.95);
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
                onVent: (action, ventId) => widget.roomManager.sendVent(action, ventId),
                onSabotage: (type) => widget.roomManager.sendSabotage(type),
                onMeeting: widget.roomManager.callEmergencyMeeting,
                onTaskOpen: (taskId) => setState(() => _activeTask = taskId),
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
    return Container(
      color: const Color(0xFF080E1C),
      child: CustomPaint(
        painter: _StationMapPainter(
          state: state,
          localX: localX,
          localY: localY,
          localAnimation: localAnimation,
        ),
        size: MediaQuery.of(context).size,
      ),
    );
  }
}

class _StationMapPainter extends CustomPainter {
  final GameState state;
  final double localX;
  final double localY;
  final String localAnimation;

  _StationMapPainter({
    required this.state,
    required this.localX,
    required this.localY,
    required this.localAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw simple placeholder map (will be replaced with tilemap renderer)
    final roomPaint = Paint()..color = const Color(0xFF111827);
    final wallPaint = Paint()..color = const Color(0xFF1E2D45);
    final tealPaint = Paint()..color = PhantomTheme.teal.withAlpha(40);

    // Rooms
    final rooms = [
      Rect.fromLTWH(0.05, 0.05, 0.35, 0.2),   // Command Bridge
      Rect.fromLTWH(0.6,  0.05, 0.35, 0.2),   // Comms Array
      Rect.fromLTWH(0.2,  0.35, 0.6,  0.25),  // Research Lab
      Rect.fromLTWH(0.05, 0.7,  0.35, 0.25),  // Engineering Bay
      Rect.fromLTWH(0.6,  0.7,  0.35, 0.25),  // Life Support
    ];

    for (final r in rooms) {
      canvas.drawRect(
        Rect.fromLTWH(r.left * size.width, r.top * size.height, r.width * size.width, r.height * size.height),
        roomPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(r.left * size.width, r.top * size.height, r.width * size.width, r.height * size.height),
        wallPaint..style = PaintingStyle.stroke..strokeWidth = 2,
      );
    }

    // Corridors
    _drawRect(canvas, size, Rect.fromLTWH(0.38, 0.1,  0.24, 0.08), roomPaint);
    _drawRect(canvas, size, Rect.fromLTWH(0.38, 0.55, 0.24, 0.2 ), roomPaint);
    _drawRect(canvas, size, Rect.fromLTWH(0.15, 0.25, 0.08, 0.12), roomPaint);
    _drawRect(canvas, size, Rect.fromLTWH(0.77, 0.25, 0.08, 0.12), roomPaint);

    // Task zones (glowing dots)
    for (final zone in _taskZones) {
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

    // Other players
    for (final p in state.players.values) {
      if (p.id == state.localPlayerId) continue;
      if (p.inVent) continue;
      _drawPlayer(canvas, size, p.x, p.y, p.color, p.name, p.isGhost);
    }

    // Local player
    _drawPlayer(canvas, size, localX, localY,
      state.localPlayer?.color ?? PhantomTheme.teal,
      state.localPlayer?.name ?? '',
      state.localPlayer?.isGhost ?? false,
      isLocal: true,
    );
  }

  static const _taskZones = [
    Offset(0.12, 0.12), // Command Bridge — Nav Cal
    Offset(0.25, 0.12), // Command Bridge — ID Verify
    Offset(0.68, 0.12), // Comms — Signal Boost
    Offset(0.80, 0.12), // Comms — Satellite Align
    Offset(0.35, 0.47), // Research Lab — Sample Analysis
    Offset(0.55, 0.47), // Research Lab — Data Upload
    Offset(0.15, 0.80), // Engineering — Reactor Align
    Offset(0.28, 0.80), // Engineering — Power Routing
    Offset(0.68, 0.80), // Life Support — Air Scrubber
    Offset(0.82, 0.80), // Life Support — Filter Replace
  ];

  void _drawRect(Canvas c, Size s, Rect r, Paint p) {
    c.drawRect(Rect.fromLTWH(r.left * s.width, r.top * s.height, r.width * s.width, r.height * s.height), p);
  }

  void _drawPlayer(Canvas canvas, Size size, double x, double y, Color color, String name, bool isGhost, {bool isLocal = false}) {
    final cx = x * size.width;
    final cy = y * size.height;
    final alpha = isGhost ? 120 : 255;
    final paint = Paint()..color = color.withAlpha(alpha);

    // Body (simple stand-in for sprite)
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 26), paint);
    // Visor
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 6), width: 12, height: 8),
      Paint()..color = Colors.lightBlueAccent.withAlpha(200),
    );
    // Local player ring
    if (isLocal) {
      canvas.drawCircle(Offset(cx, cy), 16, Paint()
        ..color = Colors.white.withAlpha(60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
      );
    }
    // Name label
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(color: Colors.white.withAlpha(alpha), fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 16));
  }

  @override
  bool shouldRepaint(covariant _StationMapPainter old) => true;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Task progress
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PROTOCOLS', style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 10, letterSpacing: 1)),
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
  final void Function(String action, String ventId) onVent;
  final void Function(String type) onSabotage;
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
    required this.onVent,
    required this.onSabotage,
    required this.onMeeting,
    required this.onTaskOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (!localAlive) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('You are a ghost. Spectate only.',
          style: TextStyle(color: PhantomTheme.textSecondary), textAlign: TextAlign.center),
      );
    }

    final local = state.localPlayer;
    final pendingTasks = local?.assignedTasks.where((t) => !local.completedTasks.contains(t)).toList() ?? [];
    final canReport = nearbyBodies.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: PhantomTheme.panelBg.withAlpha(220),
        border: const Border(top: BorderSide(color: PhantomTheme.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // GUARDIAN actions
              if (!isPhantom) ...[
                _ActionBtn(
                  icon: Icons.build_outlined,
                  label: 'TASK',
                  color: PhantomTheme.teal,
                  enabled: pendingTasks.isNotEmpty,
                  onTap: pendingTasks.isNotEmpty ? () => _showTaskPicker(context, pendingTasks) : null,
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
                  label: 'ELIMINATE',
                  color: PhantomTheme.red,
                  enabled: nearbyPlayers.isNotEmpty,
                  onTap: nearbyPlayers.isNotEmpty ? () => _showKillPicker(context) : null,
                ),
                _ActionBtn(
                  icon: Icons.subway_outlined,
                  label: 'PHASE',
                  color: PhantomTheme.purple,
                  enabled: true,
                  onTap: () => onVent('enter', 'nearest'),
                ),
                _ActionBtn(
                  icon: Icons.flash_on_outlined,
                  label: 'SABOTAGE',
                  color: Colors.orange,
                  enabled: room?.activeSabotage == SabotageType.none,
                  onTap: room?.activeSabotage == SabotageType.none ? () => _showSabotagePicker(context) : null,
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

  void _showTaskPicker(BuildContext context, List<String> tasks) {
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
