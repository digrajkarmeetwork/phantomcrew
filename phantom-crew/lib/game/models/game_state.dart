import 'package:flutter/foundation.dart';
import 'player_model.dart';
import 'room_model.dart';

class GameState extends ChangeNotifier {
  // Local player
  String localPlayerId = '';
  String localPlayerName = '';
  String localPlayerColor = 'cyan';

  // Room
  RoomModel? room;
  Map<String, PlayerModel> players = {};
  List<DeadBodyModel> deadBodies = [];

  // Chat
  List<ChatMessage> chatMessages = [];

  // Meeting state
  bool meetingActive = false;
  String? meetingCallerId;
  String? meetingReason; // 'button' or 'body'
  DateTime? meetingStartTime;
  static const int meetingDurationSeconds = 60;
  static const int votingDurationSeconds = 30;

  // Task progress (global)
  int totalTasks = 0;
  int completedTasks = 0;

  // Connection
  bool connected = false;
  String? connectionError;

  // Sabotage fix tracking (local)
  bool localFixingReactor = false;
  bool localFixingBlackout = false;

  PlayerModel? get localPlayer => players[localPlayerId];
  bool get isHost => localPlayer?.isHost ?? false;
  bool get isPhantom => localPlayer?.role == PlayerRole.phantomAgent;

  List<PlayerModel> get alivePlayers => players.values.where((p) => p.isAlive).toList();
  List<PlayerModel> get aliveGuardians => alivePlayers.where((p) => !p.isPhantom).toList();
  List<PlayerModel> get alivePhantoms => alivePlayers.where((p) => p.isPhantom).toList();

  double get taskProgress => totalTasks == 0 ? 0 : completedTasks / totalTasks;

  Duration get meetingTimeRemaining {
    if (meetingStartTime == null) return Duration.zero;
    final elapsed = DateTime.now().difference(meetingStartTime!);
    const total = Duration(seconds: meetingDurationSeconds + votingDurationSeconds);
    final remaining = total - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isVotingPhase {
    if (meetingStartTime == null) return false;
    final elapsed = DateTime.now().difference(meetingStartTime!);
    return elapsed.inSeconds >= meetingDurationSeconds;
  }

  void updatePlayer(PlayerModel player) {
    players[player.id] = player;
    notifyListeners();
  }

  void updatePlayerPosition(String id, double x, double y, String animation) {
    final p = players[id];
    if (p == null) return;
    players[id] = p.copyWith(x: x, y: y, animation: animation);
    notifyListeners();
  }

  void markPlayerDead(String id, double x, double y) {
    final p = players[id];
    if (p == null) return;
    players[id] = p.copyWith(state: PlayerState.ghost);
    deadBodies.add(DeadBodyModel(
      victimId: id,
      victimName: p.name,
      victimColorKey: p.colorKey,
      x: x,
      y: y,
    ));
    notifyListeners();
  }

  void ejectPlayer(String id) {
    final p = players[id];
    if (p == null) return;
    players[id] = p.copyWith(state: PlayerState.dead);
    notifyListeners();
  }

  void startMeeting(String callerId, String reason) {
    meetingActive = true;
    meetingCallerId = callerId;
    meetingReason = reason;
    meetingStartTime = DateTime.now();
    // Reset votes
    for (final p in players.values) {
      players[p.id] = p.copyWith(hasVoted: false, votedFor: null);
    }
    notifyListeners();
  }

  void endMeeting() {
    meetingActive = false;
    meetingCallerId = null;
    meetingReason = null;
    meetingStartTime = null;
    chatMessages.clear();
    room?.voteResults.clear();
    notifyListeners();
  }

  void recordVote(String voterId, String targetId) {
    final voter = players[voterId];
    if (voter == null || voter.hasVoted) return;
    players[voterId] = voter.copyWith(hasVoted: true, votedFor: targetId);

    final current = room?.voteResults[targetId] ?? 0;
    room?.voteResults[targetId] = current + 1;
    notifyListeners();
  }

  void addChatMessage(ChatMessage message) {
    chatMessages.add(message);
    notifyListeners();
  }

  void completeTask(String playerId, String taskId) {
    final p = players[playerId];
    if (p == null) return;
    final updated = {...p.completedTasks, taskId};
    players[playerId] = p.copyWith(completedTasks: updated);
    completedTasks++;
    notifyListeners();
  }

  void setSabotage(SabotageType type, {String? sealedZone}) {
    if (room == null) return;
    room!.activeSabotage = type;
    room!.sabotageStartTime = type != SabotageType.none ? DateTime.now() : null;
    room!.sealedZone = type == SabotageType.airlockBreach ? sealedZone : null;
    room!.fixingPanels.clear();
    notifyListeners();
  }

  void clearSabotage() {
    setSabotage(SabotageType.none);
  }

  void setConnected(bool value, {String? error}) {
    connected = value;
    connectionError = error;
    notifyListeners();
  }

  /// Public wrapper so external classes (RoomManager) can trigger UI updates.
  void notify() => notifyListeners();

  void reset() {
    room = null;
    players = {};
    deadBodies = [];
    chatMessages = [];
    meetingActive = false;
    meetingCallerId = null;
    meetingReason = null;
    meetingStartTime = null;
    totalTasks = 0;
    completedTasks = 0;
    localFixingReactor = false;
    localFixingBlackout = false;
    notifyListeners();
  }
}

class ChatMessage {
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });
}
