import 'package:flutter/material.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import '../network/game_protocol.dart';
import '../network/relay_client.dart';
import '../network/room_manager.dart';
import 'role_reveal.dart';

const List<String> _colorKeys = ['cyan', 'red', 'orange', 'purple', 'green', 'pink', 'white', 'yellow'];
const List<String> _visors = ['standard', 'cracked', 'holographic', 'thermal'];
const List<String> _emblems = ['cmc', 'star', 'circuit', 'rift'];

class LobbyScreen extends StatefulWidget {
  final GameState state;
  final RelayClient relay;
  final RoomManager roomManager;
  const LobbyScreen({super.key, required this.state, required this.relay, required this.roomManager});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String _selectedColor = 'cyan';
  String _selectedVisor = 'standard';
  String _selectedEmblem = 'cmc';

  @override
  void initState() {
    super.initState();
    widget.relay.addHandler(_onMessage);
    widget.state.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.relay.removeHandler(_onMessage);
    widget.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onMessage(PhantomMessage msg) {
    if (msg.type == MsgType.startGame || msg.type == MsgType.roleAssign) {
      if (mounted) setState(() {});
    }
  }

  void _onStateChange() {
    if (!mounted) return;
    final room = widget.state.room;
    if (room?.phase == RoomPhase.roleReveal) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoleRevealScreen(
        state: widget.state,
        relay: widget.relay,
        roomManager: widget.roomManager,
      )));
    } else {
      setState(() {});
    }
  }

  void _startGame() {
    if (!widget.state.isHost) return;
    widget.roomManager.startGame();
  }

  void _updateCosmetics() {
    final p = widget.state.localPlayer;
    if (p == null) return;
    widget.state.updatePlayer(p.copyWith(
      colorKey: _selectedColor,
      cosmeticVisor: _selectedVisor,
      cosmeticEmblem: _selectedEmblem,
    ));
    // Broadcast update
    widget.relay.send(PhantomMessage(
      type: MsgType.playerUpdate,
      room: widget.state.room?.name,
      sender: widget.state.localPlayerId,
      data: {
        'colorKey': _selectedColor,
        'cosmeticVisor': _selectedVisor,
        'cosmeticEmblem': _selectedEmblem,
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.state.room;
    final players = widget.state.players.values.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          room?.name ?? 'LOBBY',
          style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.roomManager.leaveRoom();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('LEAVE', style: TextStyle(color: PhantomTheme.red)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: widget.state.connected ? 0 : 32,
            color: PhantomTheme.red.withAlpha(30),
            child: const Center(child: Text('Reconnecting...', style: TextStyle(color: PhantomTheme.red, fontSize: 12))),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Players list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CREW (${players.length}/${room?.maxPlayers ?? 8})',
                        style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 12, letterSpacing: 1)),
                      Text('Waiting for host to start...',
                        style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...players.map((p) => _PlayerRow(player: p, isLocal: p.id == widget.state.localPlayerId)),
                  const SizedBox(height: 24),
                  // Cosmetics
                  const Text('CUSTOMIZE', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 12, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  PhantomCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SUIT COLOUR', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _colorKeys.map((c) => GestureDetector(
                          onTap: () {
                            setState(() => _selectedColor = c);
                            _updateCosmetics();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: PhantomTheme.playerColors[c],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == c ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('VISOR', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _visors.map((v) => _ChipButton(
                          label: v.toUpperCase(),
                          selected: _selectedVisor == v,
                          onTap: () { setState(() => _selectedVisor = v); _updateCosmetics(); },
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('EMBLEM', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _emblems.map((e) => _ChipButton(
                          label: e.toUpperCase(),
                          selected: _selectedEmblem == e,
                          onTap: () { setState(() => _selectedEmblem = e); _updateCosmetics(); },
                        )).toList(),
                      ),
                    ],
                  )),
                ],
              ),
            ),
          ),
          if (widget.state.isHost)
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: players.length >= 2 ? _startGame : null,
                child: const Text('START MISSION'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Waiting for host to start...',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final PlayerModel player;
  final bool isLocal;
  const _PlayerRow({required this.player, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLocal ? PhantomTheme.teal.withAlpha(20) : PhantomTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isLocal ? PhantomTheme.teal.withAlpha(80) : PhantomTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: player.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(
            player.name,
            style: TextStyle(
              color: isLocal ? PhantomTheme.teal : PhantomTheme.textPrimary,
              fontWeight: isLocal ? FontWeight.bold : FontWeight.normal,
            ),
          )),
          if (player.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: PhantomTheme.purple.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('HOST', style: TextStyle(color: PhantomTheme.purple, fontSize: 10, fontFamily: 'Orbitron')),
            ),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChipButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? PhantomTheme.teal.withAlpha(30) : PhantomTheme.darkBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? PhantomTheme.teal : PhantomTheme.divider),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? PhantomTheme.teal : PhantomTheme.textSecondary,
          fontSize: 11,
          fontFamily: 'Orbitron',
        )),
      ),
    );
  }
}
