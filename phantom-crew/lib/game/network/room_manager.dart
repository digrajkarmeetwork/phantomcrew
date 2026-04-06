import 'dart:async';
import 'dart:math';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import '../models/station_map.dart';
import 'game_protocol.dart';
import 'relay_client.dart';

const List<String> _taskPool = [
  'navigation_calibration',
  'id_verification',
  'reactor_alignment',
  'power_routing',
  'sample_analysis',
  'data_upload',
  'air_scrubber',
  'filter_replace',
  'signal_boost',
  'satellite_align',
];

const List<String> _colorPool = [
  'cyan', 'red', 'orange', 'purple', 'green', 'pink', 'white', 'yellow',
];

class RoomManager {
  final RelayClient relay;
  final GameState state;

  RoomManager({required this.relay, required this.state}) {
    relay.addHandler(_handleMessage);
  }

  // ── Host actions ─────────────────────────────────────────────────────────

  void createRoom(String roomName, {int maxPlayers = 8, int phantomCount = 2}) {
    state.room = RoomModel(
      name: roomName,
      hostId: state.localPlayerId,
      maxPlayers: maxPlayers,
      phantomCount: phantomCount,
    );

    // Add local player as host
    final localPlayer = PlayerModel(
      id: state.localPlayerId,
      name: state.localPlayerName,
      colorKey: state.localPlayerColor,
      isHost: true,
      isLocal: true,
    );
    state.updatePlayer(localPlayer);

    relay.send(PhantomMessage.hostRoom(
      roomName,
      state.localPlayerId,
      maxPlayers: maxPlayers,
      phantomCount: phantomCount,
    ));
  }

  void startGame() {
    if (!state.isHost) return;
    final room = state.room;
    if (room == null) return;

    final playerList = state.players.values.toList();
    final rng = Random();

    // Assign colours (ensure unique)
    final availableColors = List<String>.from(_colorPool);
    availableColors.shuffle(rng);
    for (int i = 0; i < playerList.length; i++) {
      final p = playerList[i];
      state.players[p.id] = p.copyWith(
        colorKey: i < availableColors.length ? availableColors[i] : 'cyan',
      );
    }

    // Assign roles
    final indices = List.generate(playerList.length, (i) => i)..shuffle(rng);
    final phantomIndices = indices.take(room.phantomCount).toSet();
    for (int i = 0; i < playerList.length; i++) {
      final p = playerList[i];
      state.players[p.id] = state.players[p.id]!.copyWith(
        role: phantomIndices.contains(i) ? PlayerRole.phantomAgent : PlayerRole.guardian,
      );
    }

    // Assign tasks (3 per guardian, shuffled)
    final guardians = state.players.values.where((p) => !p.isPhantom).toList();
    int totalTasks = 0;
    for (final guardian in guardians) {
      final tasks = List<String>.from(_taskPool)..shuffle(rng);
      final assigned = tasks.take(3).toList();
      state.players[guardian.id] = state.players[guardian.id]!.copyWith(assignedTasks: assigned);
      totalTasks += assigned.length;
    }
    state.totalTasks = totalTasks;

    // Broadcast role assignments to each player
    for (final p in state.players.values) {
      relay.send(PhantomMessage(
        type: MsgType.roleAssign,
        room: room.name,
        sender: state.localPlayerId,
        data: {
          'targetPlayer': p.id,
          'role': p.role.name,
          'colorKey': p.colorKey,
          'assignedTasks': p.assignedTasks,
          'allPlayers': state.players.values.map((pl) => {
            'id': pl.id,
            'name': pl.name,
            'colorKey': pl.colorKey,
            'isHost': pl.isHost,
          }).toList(),
        },
      ));
    }

    relay.send(PhantomMessage(
      type: MsgType.startGame,
      room: room.name,
      sender: state.localPlayerId,
      data: {'totalTasks': totalTasks},
    ));

    // Host must also update local state (relay doesn't echo back to sender)
    state.totalTasks = totalTasks;
    state.room?.phase = RoomPhase.roleReveal;
    state.notify();
  }

  // ── Guest actions ─────────────────────────────────────────────────────────

  void joinRoom(String roomName) {
    relay.send(PhantomMessage.joinRoom(
      roomName,
      state.localPlayerId,
      state.localPlayerName,
      state.localPlayerColor,
    ));
  }

  void leaveRoom() {
    final room = state.room;
    if (room == null) return;
    relay.send(PhantomMessage(
      type: MsgType.clientLeft,
      room: room.name,
      sender: state.localPlayerId,
    ));
    state.reset();
  }

  void requestRoomList() {
    relay.send(PhantomMessage.listRooms());
  }

  // ── Gameplay actions ──────────────────────────────────────────────────────

  void sendMove(double x, double y, String animation) {
    final room = state.room;
    if (room == null) return;
    relay.send(PhantomMessage.playerMove(room.name, state.localPlayerId, x, y, animation));
  }

  void sendKill(String victimId, double x, double y) {
    final room = state.room;
    if (room == null) return;
    final local = state.localPlayer;
    if (local == null || !local.canKill) return;
    // Set cooldown timestamp
    state.players[local.id] = local.copyWith(lastKillTime: DateTime.now());
    state.notify();
    relay.send(PhantomMessage.kill(room.name, state.localPlayerId, victimId, x, y));
  }

  void sendReport(String victimId) {
    final room = state.room;
    if (room == null) return;
    relay.send(PhantomMessage.reportBody(room.name, state.localPlayerId, victimId));
  }

  void sendVent(String action, String ventId, {String? destinationVentId, double? destX, double? destY}) {
    final room = state.room;
    if (room == null) return;
    // Set vent cooldown on enter
    if (action == 'enter') {
      final local = state.localPlayer;
      if (local != null) {
        state.players[local.id] = local.copyWith(lastVentTime: DateTime.now());
        state.notify();
      }
    }
    relay.send(PhantomMessage.vent(
      room.name, state.localPlayerId, action, ventId,
      destinationVentId: destinationVentId,
      destX: destX,
      destY: destY,
    ));
  }

  void sendSabotage(String sabotageType) {
    final room = state.room;
    if (room == null) return;
    final local = state.localPlayer;
    if (local == null || !local.canSabotage) return;
    state.players[local.id] = local.copyWith(lastSabotageTime: DateTime.now());
    state.notify();

    // For airlock breach, pick a random zone to seal
    String? sealedZone;
    if (sabotageType == 'airlockBreach') {
      final zones = StationMap.rooms.keys.toList();
      zones.shuffle();
      sealedZone = zones.first;
    }

    final msg = PhantomMessage.sabotage(room.name, state.localPlayerId, sabotageType);
    // Add sealedZone to the message data if applicable
    if (sealedZone != null) {
      relay.send(PhantomMessage(
        type: msg.type,
        room: msg.room,
        sender: msg.sender,
        data: {...msg.data, 'sealedZone': sealedZone},
      ));
    } else {
      relay.send(msg);
    }
  }

  void sendFixSabotage(String sabotageType, String panel) {
    final room = state.room;
    if (room == null) return;
    relay.send(PhantomMessage.fixSabotage(room.name, state.localPlayerId, sabotageType, panel));
  }

  void sendTaskComplete(String taskId) {
    final room = state.room;
    if (room == null) return;
    state.completeTask(state.localPlayerId, taskId);
    relay.send(PhantomMessage.taskComplete(
      room.name,
      state.localPlayerId,
      taskId,
      state.taskProgress,
    ));
  }

  void callEmergencyMeeting() {
    final room = state.room;
    if (room == null) return;
    relay.send(PhantomMessage.emergencyMeeting(room.name, state.localPlayerId));
  }

  void sendChat(String text) {
    final room = state.room;
    if (room == null) return;
    relay.send(PhantomMessage.chat(
      room.name,
      state.localPlayerId,
      state.localPlayerName,
      text,
    ));
  }

  void sendVote(String targetId) {
    final room = state.room;
    if (room == null) return;
    relay.send(PhantomMessage.vote(room.name, state.localPlayerId, targetId));
  }

  // ── Message handler ───────────────────────────────────────────────────────

  void _handleMessage(PhantomMessage msg) {
    switch (msg.type) {
      case MsgType.clientJoined:
        _onClientJoined(msg);
      case MsgType.clientLeft:
        _onClientLeft(msg);
      case MsgType.roleAssign:
        _onRoleAssign(msg);
      case MsgType.startGame:
        _onStartGame(msg);
      case MsgType.playerMove:
        _onPlayerMove(msg);
      case MsgType.kill:
        _onKill(msg);
      case MsgType.reportBody:
        _onReportBody(msg);
      case MsgType.ventAction:
        _onVentAction(msg);
      case MsgType.sabotage:
        _onSabotage(msg);
      case MsgType.fixSabotage:
        _onFixSabotage(msg);
      case MsgType.taskComplete:
        _onTaskComplete(msg);
      case MsgType.emergencyMeeting:
        _onEmergencyMeeting(msg);
      case MsgType.chatMessage:
        _onChat(msg);
      case MsgType.vote:
        _onVote(msg);
      case MsgType.meetingEnd:
        _onMeetingEnd(msg);
      case MsgType.gameOver:
        _onGameOver(msg);
      case MsgType.roomList:
        break; // Handled directly by JoinScreen
      default:
        break;
    }
  }

  void _onClientJoined(PhantomMessage msg) {
    final id = msg.sender ?? msg.data['id'] as String? ?? '';
    final name = msg.data['playerName'] as String? ?? 'Unknown';
    final colorKey = msg.data['colorKey'] as String? ?? 'cyan';
    if (id.isEmpty || state.players.containsKey(id)) return;
    state.updatePlayer(PlayerModel(id: id, name: name, colorKey: colorKey));
  }

  void _onClientLeft(PhantomMessage msg) {
    final id = msg.sender ?? '';
    state.players.remove(id);
    state.notify();
  }

  void _onRoleAssign(PhantomMessage msg) {
    final targetId = msg.data['targetPlayer'] as String? ?? '';
    if (targetId != state.localPlayerId) return;

    final role = PlayerRole.values.firstWhere(
      (r) => r.name == msg.data['role'],
      orElse: () => PlayerRole.guardian,
    );
    final tasks = (msg.data['assignedTasks'] as List<dynamic>?)?.cast<String>() ?? [];

    // Update all players from the full roster
    final allPlayers = msg.data['allPlayers'] as List<dynamic>? ?? [];
    for (final pd in allPlayers) {
      final map = pd as Map<String, dynamic>;
      final pid = map['id'] as String;
      final existing = state.players[pid];
      state.players[pid] = PlayerModel(
        id: pid,
        name: map['name'] as String,
        colorKey: map['colorKey'] as String? ?? 'cyan',
        isHost: map['isHost'] as bool? ?? false,
        isLocal: pid == state.localPlayerId,
        role: pid == state.localPlayerId ? role : PlayerRole.guardian,
        assignedTasks: pid == state.localPlayerId ? tasks : (existing?.assignedTasks ?? []),
      );
    }
    state.notify();
  }

  void _onStartGame(PhantomMessage msg) {
    state.totalTasks = msg.data['totalTasks'] as int? ?? 0;
    state.room?.phase = RoomPhase.roleReveal;
    state.notify();
  }

  void _onPlayerMove(PhantomMessage msg) {
    final id = msg.sender ?? '';
    if (id == state.localPlayerId) return;
    state.updatePlayerPosition(
      id,
      (msg.data['x'] as num).toDouble(),
      (msg.data['y'] as num).toDouble(),
      msg.data['anim'] as String? ?? 'idle',
    );
  }

  void _onKill(PhantomMessage msg) {
    final victimId = msg.data['victim'] as String? ?? '';
    final x = (msg.data['x'] as num?)?.toDouble() ?? 0.5;
    final y = (msg.data['y'] as num?)?.toDouble() ?? 0.5;
    state.markPlayerDead(victimId, x, y);
    _checkWinConditions();
  }

  void _onReportBody(PhantomMessage msg) {
    final victimId = msg.data['victim'] as String? ?? '';
    for (final body in state.deadBodies) {
      if (body.victimId == victimId) {
        body.reported = true;
        break;
      }
    }
    state.startMeeting(msg.sender ?? '', 'body');
    _scheduleBotVotes();
  }

  void _onVentAction(PhantomMessage msg) {
    final id = msg.sender ?? '';
    final action = msg.data['action'] as String? ?? '';
    final p = state.players[id];
    if (p == null) return;

    if (action == 'enter') {
      state.players[id] = p.copyWith(inVent: true);
    } else if (action == 'travel') {
      final destX = (msg.data['destX'] as num?)?.toDouble();
      final destY = (msg.data['destY'] as num?)?.toDouble();
      if (destX != null && destY != null) {
        state.players[id] = p.copyWith(x: destX, y: destY, inVent: true);
      }
    } else if (action == 'exit') {
      state.players[id] = p.copyWith(inVent: false);
    }
    state.notify();
  }

  void _onSabotage(PhantomMessage msg) {
    final type = SabotageType.values.firstWhere(
      (s) => s.name == msg.data['sabotageType'],
      orElse: () => SabotageType.none,
    );
    final sealedZone = msg.data['sealedZone'] as String?;
    state.setSabotage(type, sealedZone: sealedZone);
  }

  void _onFixSabotage(PhantomMessage msg) {
    final room = state.room;
    if (room == null) return;

    final panel = msg.data['panel'] as String? ?? '';
    final playerId = msg.sender ?? '';
    final action = msg.data['action'] as String? ?? 'hold';
    final sabotageType = room.activeSabotage.name;

    if (action == 'cancel') {
      // Player released the fix panel
      room.fixingPanels.remove(panel);
      state.notify();
      return;
    }

    // Register player on fix panel
    room.fixingPanels[panel] = playerId;
    state.notify();

    // Host checks if fix conditions are met
    if (!state.isHost) return;

    final required = StationMap.fixRequirements[sabotageType] ?? 1;
    final panels = StationMap.fixPanels[sabotageType] ?? {};

    if (required == 1) {
      // Single player at correct panel clears sabotage
      if (panels.containsKey(panel)) {
        state.clearSabotage();
        room.fixingPanels.clear();
        relay.send(PhantomMessage(
          type: MsgType.fixSabotage,
          room: room.name,
          sender: state.localPlayerId,
          data: {'action': 'cleared', 'sabotageType': sabotageType},
        ));
      }
    } else {
      // Multi-player: check if all panels have different players holding them
      final activePanels = panels.keys.where((p) => room.fixingPanels.containsKey(p)).toList();
      final uniquePlayers = activePanels.map((p) => room.fixingPanels[p]).toSet();
      if (activePanels.length >= required && uniquePlayers.length >= required) {
        state.clearSabotage();
        room.fixingPanels.clear();
        relay.send(PhantomMessage(
          type: MsgType.fixSabotage,
          room: room.name,
          sender: state.localPlayerId,
          data: {'action': 'cleared', 'sabotageType': sabotageType},
        ));
      }
    }
  }

  void _onTaskComplete(PhantomMessage msg) {
    final playerId = msg.sender ?? '';
    final taskId = msg.data['taskId'] as String? ?? '';
    if (playerId != state.localPlayerId) {
      state.completeTask(playerId, taskId);
    }
    _checkWinConditions();
  }

  void _onEmergencyMeeting(PhantomMessage msg) {
    state.startMeeting(msg.sender ?? '', msg.data['reason'] as String? ?? 'button');
    _scheduleBotVotes();
  }

  void _scheduleBotVotes() {
    if (!state.isHost) return;
    final rng = Random();
    final bots = state.alivePlayers.where((p) => p.isBot).toList();
    for (final bot in bots) {
      final delay = 3 + rng.nextInt(8); // 3-10 seconds
      Timer(Duration(seconds: delay), () {
        if (!state.meetingActive) return;
        final alive = state.alivePlayers.where((p) => p.id != bot.id).toList();
        // Bots vote randomly: 40% skip, 60% vote for someone
        String target;
        if (alive.isEmpty || rng.nextDouble() < 0.4) {
          target = 'skip';
        } else {
          target = alive[rng.nextInt(alive.length)].id;
        }
        state.recordVote(bot.id, target);
        // Check if all voted
        final allVoted = state.alivePlayers.every((p) => p.hasVoted);
        if (allVoted) _resolveMeeting();
      });
    }
  }

  void _onChat(PhantomMessage msg) {
    state.addChatMessage(ChatMessage(
      senderId: msg.sender ?? '',
      senderName: msg.data['senderName'] as String? ?? 'Unknown',
      text: msg.data['text'] as String? ?? '',
      timestamp: DateTime.now(),
    ));
  }

  void _onVote(PhantomMessage msg) {
    state.recordVote(msg.sender ?? '', msg.data['target'] as String? ?? 'skip');

    // Host tallies votes and ends meeting when all alive players voted
    if (state.isHost) {
      final alive = state.alivePlayers;
      final allVoted = alive.every((p) => p.hasVoted);
      if (allVoted) _resolveMeeting();
    }
  }

  void _resolveMeeting() {
    final room = state.room;
    if (room == null) return;

    // Find player with most votes
    String ejectedId = '';
    int maxVotes = 0;
    bool tie = false;

    room.voteResults.forEach((id, votes) {
      if (votes > maxVotes) {
        maxVotes = votes;
        ejectedId = id;
        tie = false;
      } else if (votes == maxVotes && id != 'skip') {
        tie = true;
      }
    });

    if (tie || ejectedId == 'skip' || ejectedId.isEmpty) {
      ejectedId = '';
    }

    relay.send(PhantomMessage(
      type: MsgType.meetingEnd,
      room: room.name,
      sender: state.localPlayerId,
      data: {
        'ejected': ejectedId,
        'wasPhantom': ejectedId.isNotEmpty ? (state.players[ejectedId]?.isPhantom ?? false) : null,
        'voteResults': room.voteResults,
      },
    ));
  }

  void _onMeetingEnd(PhantomMessage msg) {
    final ejectedId = msg.data['ejected'] as String? ?? '';
    if (ejectedId.isNotEmpty) {
      state.ejectPlayer(ejectedId);
    }
    state.endMeeting();
    _checkWinConditions();
  }

  void _onGameOver(PhantomMessage msg) {
    final condition = WinCondition.values.firstWhere(
      (w) => w.name == msg.data['condition'],
      orElse: () => WinCondition.none,
    );
    if (state.room != null) {
      state.room!.winCondition = condition;
      state.room!.phase = RoomPhase.ended;
    }
    state.notify();
  }

  void _checkWinConditions() {
    if (!state.isHost) return;
    final room = state.room;
    if (room == null || room.phase != RoomPhase.playing) return;

    WinCondition? result;

    // Guardians complete all tasks
    if (state.taskProgress >= 1.0) {
      result = WinCondition.guardiansTasksComplete;
    }

    // All phantoms eliminated
    if (state.alivePhantoms.isEmpty) {
      result = WinCondition.guardiansEliminatedPhantoms;
    }

    // Phantoms outnumber (or equal) guardians
    if (state.alivePhantoms.length >= state.aliveGuardians.length) {
      result = WinCondition.phantomsOutnumber;
    }

    if (result != null) {
      relay.send(PhantomMessage(
        type: MsgType.gameOver,
        room: room.name,
        sender: state.localPlayerId,
        data: {'condition': result.name},
      ));
    }
  }

  void dispose() {
    relay.removeHandler(_handleMessage);
  }
}
