import 'package:flutter/material.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../network/game_protocol.dart';
import '../network/relay_client.dart';
import '../network/room_manager.dart';
import 'lobby_screen.dart';

class JoinScreen extends StatefulWidget {
  final GameState state;
  final RelayClient relay;
  const JoinScreen({super.key, required this.state, required this.relay});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  List<RoomEntry> _rooms = [];
  bool _loading = false;
  String? _error;
  RoomEntry? _selected;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() { _loading = true; _error = null; });
    widget.relay.addHandler(_onMessage);
    await widget.relay.connect();
    if (!widget.relay.isConnected) {
      setState(() { _loading = false; _error = 'Cannot connect to relay server.'; });
      return;
    }
    widget.relay.send(PhantomMessage.listRooms());
  }

  void _onMessage(PhantomMessage msg) {
    if (msg.type == MsgType.roomList) {
      final rooms = parseRoomList(msg);
      if (mounted) setState(() { _rooms = rooms; _loading = false; });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    widget.relay.send(PhantomMessage.listRooms());
    await Future.delayed(const Duration(seconds: 1));
    if (mounted && _loading) setState(() => _loading = false);
  }

  void _join() {
    if (_selected == null) return;
    final rm = RoomManager(relay: widget.relay, state: widget.state);
    rm.joinRoom(_selected!.name);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LobbyScreen(
      state: widget.state,
      relay: widget.relay,
      roomManager: rm,
    )));
  }

  @override
  void dispose() {
    widget.relay.removeHandler(_onMessage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PhantomTheme.teal),
        title: const Text('JOIN ROOM', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: PhantomTheme.teal),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PhantomTheme.red.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PhantomTheme.red.withAlpha(80)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber, color: PhantomTheme.red, size: 18),
                const SizedBox(width: 8),
                Text(_error!, style: const TextStyle(color: PhantomTheme.red)),
              ]),
            ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: PhantomTheme.teal))
              : _rooms.isEmpty
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off, color: PhantomTheme.textSecondary, size: 48),
                      const SizedBox(height: 16),
                      Text('No open stations found.', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _refresh, child: const Text('REFRESH')),
                    ],
                  ))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _RoomTile(
                      room: _rooms[i],
                      selected: _selected?.name == _rooms[i].name,
                      onTap: () => setState(() => _selected = _rooms[i]),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: (_selected != null && !_selected!.isFull) ? _join : null,
              child: const Text('BOARD STATION'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final RoomEntry room;
  final bool selected;
  final VoidCallback onTap;
  const _RoomTile({required this.room, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: room.isFull ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? PhantomTheme.teal.withAlpha(25) : PhantomTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? PhantomTheme.teal : PhantomTheme.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.rocket_launch_outlined,
              color: room.isFull ? PhantomTheme.textSecondary : PhantomTheme.teal,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name, style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 15,
                    color: PhantomTheme.textPrimary,
                  )),
                  const SizedBox(height: 2),
                  Text(
                    '${room.playerCount} / ${room.maxPlayers} crew',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (room.isFull)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PhantomTheme.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('FULL', style: TextStyle(color: PhantomTheme.red, fontSize: 12, fontFamily: 'Orbitron')),
              ),
          ],
        ),
      ),
    );
  }
}
