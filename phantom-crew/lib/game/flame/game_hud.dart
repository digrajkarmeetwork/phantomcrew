import 'package:flutter/material.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import '../models/station_map.dart';
import '../network/room_manager.dart';
import '../tasks/task_registry.dart';
import 'phantom_game.dart';

/// Builds the HUD overlay widget tree for the Flame game.
/// This is registered as a Flame overlay and rendered on top of the game canvas.
class GameHudOverlay extends StatefulWidget {
  final PhantomGame game;
  const GameHudOverlay({super.key, required this.game});

  @override
  State<GameHudOverlay> createState() => _GameHudOverlayState();
}

class _GameHudOverlayState extends State<GameHudOverlay> {
  String? _activeTask;
  String? _currentVentId;

  GameState get state => widget.game.state;
  RoomManager get roomManager => widget.game.roomManager;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChange);
  }

  @override
  void dispose() {
    state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  double get _localX => state.localPlayer?.x ?? 0.5;
  double get _localY => state.localPlayer?.y ?? 0.5;

  List<PlayerModel> get _nearbyAlive {
    const radius = 0.08;
    return state.alivePlayers.where((p) {
      if (p.id == state.localPlayerId) return false;
      final dx = p.x - _localX;
      final dy = p.y - _localY;
      return (dx * dx + dy * dy) < (radius * radius);
    }).toList();
  }

  List<DeadBodyModel> get _nearbyBodies {
    const radius = 0.08;
    return state.deadBodies.where((b) {
      if (b.reported) return false;
      final dx = b.x - _localX;
      final dy = b.y - _localY;
      return (dx * dx + dy * dy) < (radius * radius);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final local = state.localPlayer;
    final isPhantom = state.isPhantom;
    final room = state.room;

    return Stack(
      children: [
        // Top HUD
        Positioned(
          left: 0, right: 0, top: 0,
          child: SafeArea(child: TopHUD(state: state)),
        ),

        // Connection lost indicator
        if (!state.connected)
          Positioned(
            left: 0, right: 0, top: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: PhantomTheme.red.withAlpha(40),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: PhantomTheme.red)),
                    SizedBox(width: 8),
                    Text('Reconnecting...', style: TextStyle(color: PhantomTheme.red, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),

        // Bottom HUD
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            child: BottomHUD(
              state: state,
              isPhantom: isPhantom,
              localAlive: local?.isAlive ?? false,
              nearbyPlayers: _nearbyAlive,
              nearbyBodies: _nearbyBodies,
              room: room,
              onKill: (victim) => roomManager.sendKill(victim.id, victim.x, victim.y),
              onReport: (body) => roomManager.sendReport(body.victimId),
              onVentEnter: () {
                final ventId = StationMap.nearestVent(_localX, _localY);
                if (ventId != null) {
                  _currentVentId = ventId;
                  roomManager.sendVent('enter', ventId);
                  widget.game.spawnVentEffect(_localX, _localY);
                  setState(() {});
                }
              },
              onVentTravel: (destVentId) {
                final destPos = StationMap.ventPositions[destVentId];
                if (destPos != null) {
                  roomManager.sendVent('travel', _currentVentId ?? '',
                    destinationVentId: destVentId, destX: destPos.dx, destY: destPos.dy);
                  state.updatePlayerPosition(state.localPlayerId, destPos.dx, destPos.dy, 'idle');
                  _currentVentId = destVentId;
                  widget.game.spawnVentEffect(destPos.dx, destPos.dy);
                  setState(() {});
                }
              },
              onVentExit: () {
                roomManager.sendVent('exit', _currentVentId ?? '');
                widget.game.spawnVentEffect(_localX, _localY);
                _currentVentId = null;
                setState(() {});
              },
              currentVentId: _currentVentId,
              localX: _localX,
              localY: _localY,
              onSabotage: (type) => roomManager.sendSabotage(type),
              onFix: (panel) => roomManager.sendFixSabotage(room?.activeSabotage.name ?? '', panel),
              onMeeting: roomManager.callEmergencyMeeting,
              onTaskOpen: (taskId) => setState(() => _activeTask = taskId),
            ),
          ),
        ),

        // Task overlay
        if (_activeTask != null)
          TaskOverlay(
            taskId: _activeTask!,
            state: state,
            onComplete: () {
              roomManager.sendTaskComplete(_activeTask!);
              setState(() => _activeTask = null);
            },
            onClose: () => setState(() => _activeTask = null),
          ),
      ],
    );
  }
}

// ── Top HUD ─────────────────────────────────────────────────────────────────

class TopHUD extends StatelessWidget {
  final GameState state;
  const TopHUD({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final room = state.room;
    final isCommsJammed = room?.activeSabotage == SabotageType.commsJamming;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0A1A).withAlpha(200),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
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
                    value: null,
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
          if (room?.hasSabotage == true && room?.sabotageTimeRemaining != null)
            SabotageTimer(remaining: room!.sabotageTimeRemaining!),
        ],
      ),
    );
  }
}

class SabotageTimer extends StatelessWidget {
  final Duration remaining;
  const SabotageTimer({super.key, required this.remaining});

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
          Text('${secs}s', style: const TextStyle(color: PhantomTheme.red, fontFamily: 'Orbitron', fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Bottom HUD ──────────────────────────────────────────────────────────────

class BottomHUD extends StatelessWidget {
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

  const BottomHUD({
    super.key,
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
            ActionBtn(
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
    final nearbyTaskIds = _nearbyTaskIds(pendingTasks);
    final nearVentId = StationMap.nearestVent(localX, localY);
    final canEnterVent = nearVentId != null && !isInVent && (local?.canVent ?? false);
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
          if (isPhantom && isInVent) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...StationMap.ventDestinations(currentVentId!).map((destId) =>
                  ActionBtn(
                    icon: Icons.subway_outlined,
                    label: StationMap.ventNames[destId] ?? destId,
                    color: PhantomTheme.purple,
                    enabled: true,
                    onTap: () => onVentTravel(destId),
                  ),
                ),
                ActionBtn(
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
                if (!isPhantom) ...[
                  ActionBtn(
                    icon: Icons.build_outlined,
                    label: 'TASK',
                    color: PhantomTheme.teal,
                    enabled: nearbyTaskIds.isNotEmpty,
                    onTap: nearbyTaskIds.isNotEmpty ? () => _showTaskPicker(context, nearbyTaskIds) : null,
                  ),
                  if (room?.hasSabotage == true)
                    ActionBtn(
                      icon: Icons.hardware_outlined,
                      label: 'FIX',
                      color: PhantomTheme.red,
                      enabled: nearFixPanel != null,
                      onTap: nearFixPanel != null ? () => onFix(nearFixPanel) : null,
                    ),
                  ActionBtn(
                    icon: Icons.campaign_outlined,
                    label: 'MEETING',
                    color: Colors.amber,
                    enabled: (local?.meetingUsesLeft ?? 0) > 0,
                    onTap: onMeeting,
                  ),
                ],
                if (isPhantom) ...[
                  ActionBtn(
                    icon: Icons.close,
                    label: (local?.canKill ?? true) ? 'ELIMINATE' : '${local?.killCooldownRemaining}s',
                    color: PhantomTheme.red,
                    enabled: nearbyPlayers.isNotEmpty && (local?.canKill ?? false),
                    onTap: nearbyPlayers.isNotEmpty && (local?.canKill ?? false)
                      ? () => _showKillPicker(context) : null,
                  ),
                  ActionBtn(
                    icon: Icons.subway_outlined,
                    label: (local?.canVent ?? true) ? 'PHASE' : '${local?.ventCooldownRemaining}s',
                    color: PhantomTheme.purple,
                    enabled: canEnterVent,
                    onTap: canEnterVent ? onVentEnter : null,
                  ),
                  ActionBtn(
                    icon: Icons.flash_on_outlined,
                    label: (local?.canSabotage ?? true) ? 'SABOTAGE' : '${local?.sabotageCooldownRemaining}s',
                    color: Colors.orange,
                    enabled: room?.activeSabotage == SabotageType.none && (local?.canSabotage ?? false),
                    onTap: room?.activeSabotage == SabotageType.none && (local?.canSabotage ?? false)
                      ? () => _showSabotagePicker(context) : null,
                  ),
                ],
                ActionBtn(
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
    if (tasks.length == 1) { onTaskOpen(tasks.first); return; }
    showModalBottomSheet(
      context: context,
      backgroundColor: PhantomTheme.panelBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16),
            child: Text('SELECT TASK', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: PhantomTheme.textPrimary))),
          ...tasks.map((t) => ListTile(
            leading: const Icon(Icons.build_circle_outlined, color: PhantomTheme.teal),
            title: Text(TaskRegistry.displayName(t), style: const TextStyle(color: PhantomTheme.textPrimary)),
            subtitle: Text(TaskRegistry.zone(t), style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 12)),
            onTap: () { Navigator.pop(context); onTaskOpen(t); },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showKillPicker(BuildContext context) {
    if (nearbyPlayers.length == 1) { onKill(nearbyPlayers.first); return; }
    showModalBottomSheet(
      context: context,
      backgroundColor: PhantomTheme.panelBg,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16),
            child: Text('ELIMINATE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: PhantomTheme.red))),
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
          const Padding(padding: EdgeInsets.all(16),
            child: Text('SABOTAGE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.orange))),
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

// ── Action button ───────────────────────────────────────────────────────────

class ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  const ActionBtn({super.key, required this.icon, required this.label, required this.color, required this.enabled, this.onTap});

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

// ── Task overlay ────────────────────────────────────────────────────────────

class TaskOverlay extends StatelessWidget {
  final String taskId;
  final GameState state;
  final VoidCallback onComplete;
  final VoidCallback onClose;
  const TaskOverlay({super.key, required this.taskId, required this.state, required this.onComplete, required this.onClose});

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
