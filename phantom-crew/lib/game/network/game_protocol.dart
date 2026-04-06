import 'dart:convert';

/// All message types in the Phantom Crew WebSocket protocol.
enum MsgType {
  // Room management (relay layer)
  hostRoom,
  joinRoom,
  listRooms,
  roomList,
  clientJoined,
  clientLeft,
  roomClosed,

  // Lobby
  playerUpdate,
  startGame,
  roleAssign,

  // Gameplay
  playerMove,
  kill,
  reportBody,
  ventAction,
  sabotage,
  fixSabotage,
  taskComplete,
  emergencyMeeting,

  // Meeting
  chatMessage,
  vote,
  voteResult,
  meetingEnd,

  // Game end
  gameOver,

  // Misc
  ping,
  pong,
  error,
}

class PhantomMessage {
  final MsgType type;
  final String? room;
  final String? sender;
  final Map<String, dynamic> data;

  const PhantomMessage({
    required this.type,
    this.room,
    this.sender,
    this.data = const {},
  });

  String toJsonString() => jsonEncode({
    'type': type.name,
    if (room != null) 'room': room,
    if (sender != null) 'sender': sender,
    ...data,
  });

  static PhantomMessage fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final typeName = map['type'] as String? ?? '';
    final type = MsgType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => MsgType.error,
    );
    final known = {'type', 'room', 'sender'};
    return PhantomMessage(
      type: type,
      room: map['room'] as String?,
      sender: map['sender'] as String?,
      data: Map.fromEntries(map.entries.where((e) => !known.contains(e.key))),
    );
  }

  // ── Factory constructors ────────────────────────────────────────────────

  factory PhantomMessage.hostRoom(String roomName, String hostId, {int maxPlayers = 8, int phantomCount = 2}) =>
    PhantomMessage(
      type: MsgType.hostRoom,
      room: roomName,
      sender: hostId,
      data: {'maxPlayers': maxPlayers, 'phantomCount': phantomCount},
    );

  factory PhantomMessage.joinRoom(String roomName, String playerId, String playerName, String colorKey) =>
    PhantomMessage(
      type: MsgType.joinRoom,
      room: roomName,
      sender: playerId,
      data: {'playerName': playerName, 'colorKey': colorKey},
    );

  factory PhantomMessage.listRooms() => const PhantomMessage(type: MsgType.listRooms);

  factory PhantomMessage.playerMove(String room, String playerId, double x, double y, String animation) =>
    PhantomMessage(
      type: MsgType.playerMove,
      room: room,
      sender: playerId,
      data: {'x': x, 'y': y, 'anim': animation},
    );

  factory PhantomMessage.kill(String room, String killerId, String victimId, double x, double y) =>
    PhantomMessage(
      type: MsgType.kill,
      room: room,
      sender: killerId,
      data: {'victim': victimId, 'x': x, 'y': y},
    );

  factory PhantomMessage.reportBody(String room, String reporterId, String victimId) =>
    PhantomMessage(
      type: MsgType.reportBody,
      room: room,
      sender: reporterId,
      data: {'victim': victimId},
    );

  factory PhantomMessage.vent(String room, String playerId, String action, String ventId) =>
    PhantomMessage(
      type: MsgType.ventAction,
      room: room,
      sender: playerId,
      data: {'action': action, 'ventId': ventId},
    );

  factory PhantomMessage.sabotage(String room, String phantomId, String sabotageType) =>
    PhantomMessage(
      type: MsgType.sabotage,
      room: room,
      sender: phantomId,
      data: {'sabotageType': sabotageType},
    );

  factory PhantomMessage.fixSabotage(String room, String playerId, String sabotageType, String panel) =>
    PhantomMessage(
      type: MsgType.fixSabotage,
      room: room,
      sender: playerId,
      data: {'sabotageType': sabotageType, 'panel': panel},
    );

  factory PhantomMessage.taskComplete(String room, String playerId, String taskId, double progress) =>
    PhantomMessage(
      type: MsgType.taskComplete,
      room: room,
      sender: playerId,
      data: {'taskId': taskId, 'progress': progress},
    );

  factory PhantomMessage.emergencyMeeting(String room, String callerId) =>
    PhantomMessage(
      type: MsgType.emergencyMeeting,
      room: room,
      sender: callerId,
      data: {'reason': 'button'},
    );

  factory PhantomMessage.chat(String room, String senderId, String senderName, String text) =>
    PhantomMessage(
      type: MsgType.chatMessage,
      room: room,
      sender: senderId,
      data: {'senderName': senderName, 'text': text},
    );

  factory PhantomMessage.vote(String room, String voterId, String targetId) =>
    PhantomMessage(
      type: MsgType.vote,
      room: room,
      sender: voterId,
      data: {'target': targetId},
    );
}
