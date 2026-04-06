import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'game_protocol.dart';

typedef MessageHandler = void Function(PhantomMessage msg);

class RelayClient {
  static const String defaultRelayUrl = 'wss://phantomcrew-relay.onrender.com';
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration pingInterval = Duration(seconds: 25);

  final String relayUrl;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _disposed = false;
  bool _connected = false;
  bool get isConnected => _connected;

  final List<MessageHandler> _handlers = [];
  void Function(bool connected, String? error)? onConnectionChange;

  RelayClient({String? relayUrl}) : relayUrl = relayUrl ?? defaultRelayUrl;

  void addHandler(MessageHandler handler) => _handlers.add(handler);
  void removeHandler(MessageHandler handler) => _handlers.remove(handler);

  Future<void> connect() async {
    if (_disposed) return;
    _disconnect();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(relayUrl));
      await _channel!.ready;
      _connected = true;
      onConnectionChange?.call(true, null);
      _startPing();

      _sub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _connected = false;
      onConnectionChange?.call(false, e.toString());
      _scheduleReconnect();
    }
  }

  void send(PhantomMessage msg) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(msg.toJsonString());
    } catch (_) {}
  }

  void _onData(dynamic raw) {
    try {
      final msg = PhantomMessage.fromJsonString(raw as String);
      if (msg.type == MsgType.ping) {
        send(const PhantomMessage(type: MsgType.pong));
        return;
      }
      for (final h in List.of(_handlers)) {
        h(msg);
      }
    } catch (_) {}
  }

  void _onError(Object error) {
    _connected = false;
    onConnectionChange?.call(false, error.toString());
    _scheduleReconnect();
  }

  void _onDone() {
    _connected = false;
    onConnectionChange?.call(false, null);
    if (!_disposed) _scheduleReconnect();
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      send(const PhantomMessage(type: MsgType.ping));
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, connect);
  }

  void _disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  void dispose() {
    _disposed = true;
    _disconnect();
    _handlers.clear();
  }
}

/// Room listing entry returned by the relay server.
class RoomEntry {
  final String name;
  final int playerCount;
  final int maxPlayers;
  final String hostId;

  const RoomEntry({
    required this.name,
    required this.playerCount,
    required this.maxPlayers,
    required this.hostId,
  });

  factory RoomEntry.fromJson(Map<String, dynamic> json) => RoomEntry(
    name: json['name'] as String,
    playerCount: json['playerCount'] as int? ?? 0,
    maxPlayers: json['maxPlayers'] as int? ?? 8,
    hostId: json['hostId'] as String? ?? '',
  );

  bool get isFull => playerCount >= maxPlayers;
}

/// Converts the relay roomList message into a list of RoomEntry.
List<RoomEntry> parseRoomList(PhantomMessage msg) {
  final rooms = msg.data['rooms'] as List<dynamic>? ?? [];
  return rooms.map((r) => RoomEntry.fromJson(r as Map<String, dynamic>)).toList();
}
