import 'package:flutter/material.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../network/relay_client.dart';
import '../network/room_manager.dart';
import 'lobby_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  final GameState state;
  final RelayClient relay;
  const CreateRoomScreen({super.key, required this.state, required this.relay});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _roomCtrl = TextEditingController();
  int _maxPlayers = 8;
  int _phantomCount = 2;
  bool _connecting = false;

  @override
  void dispose() {
    _roomCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _roomCtrl.text.trim().isNotEmpty;

  Future<void> _create() async {
    if (!_valid) return;
    setState(() => _connecting = true);

    widget.relay.onConnectionChange = (connected, error) {
      widget.state.setConnected(connected, error: error);
    };
    await widget.relay.connect();
    if (!widget.relay.isConnected) {
      if (mounted) {
        setState(() => _connecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to relay server. Check settings.'))
        );
      }
      return;
    }

    final rm = RoomManager(relay: widget.relay, state: widget.state);
    rm.createRoom(
      _roomCtrl.text.trim(),
      maxPlayers: _maxPlayers,
      phantomCount: _phantomCount,
    );

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LobbyScreen(
        state: widget.state,
        relay: widget.relay,
        roomManager: rm,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PhantomTheme.teal),
        title: const Text('CREATE ROOM', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _roomCtrl,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'ROOM NAME',
                hintText: 'e.g. HORIZON-7',
                prefixIcon: Icon(Icons.meeting_room_outlined, color: PhantomTheme.teal),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 32),
            PhantomCard(
              child: Column(
                children: [
                  _slider('MAX PLAYERS', _maxPlayers, 2, 8, (v) => setState(() {
                    _maxPlayers = v;
                    if (_phantomCount >= _maxPlayers) _phantomCount = _maxPlayers - 1;
                  })),
                  const Divider(color: PhantomTheme.divider, height: 24),
                  _slider('PHANTOM AGENTS', _phantomCount, 1, (_maxPlayers - 1).clamp(1, 3), (v) => setState(() => _phantomCount = v)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PhantomCard(
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: PhantomTheme.textSecondary, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'With $_maxPlayers players and $_phantomCount Phantom Agent${_phantomCount > 1 ? "s" : ""}, '
                    '${_maxPlayers - _phantomCount} Guardian${(_maxPlayers - _phantomCount) > 1 ? "s" : ""} '
                    'must complete ${(_maxPlayers - _phantomCount) * 3} station protocols to win.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _connecting ? null : (_valid ? _create : null),
              child: _connecting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: PhantomTheme.darkBg))
                : const Text('LAUNCH STATION'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, int value, int min, int max, ValueChanged<int> onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 12, letterSpacing: 1)),
            Text('$value', style: const TextStyle(color: PhantomTheme.teal, fontFamily: 'Orbitron', fontSize: 18)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: PhantomTheme.teal,
          inactiveColor: PhantomTheme.divider,
          onChanged: (v) => onChange(v.round()),
        ),
      ],
    );
  }
}
