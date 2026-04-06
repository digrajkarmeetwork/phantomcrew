import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/room_model.dart';
import '../network/relay_client.dart';
import '../network/room_manager.dart';
import '../flame/phantom_game.dart';
import '../flame/game_hud.dart';
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
  late final PhantomGame _game;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    widget.state.room?.phase = RoomPhase.playing;

    _game = PhantomGame(
      state: widget.state,
      roomManager: widget.roomManager,
    );

    widget.state.addListener(_onStateChange);

    // Periodic refresh for cooldown timers and sabotage countdown
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChange);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    final room = widget.state.room;

    // Navigate to end screen
    if (room?.phase == RoomPhase.ended) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EndScreen(
        state: widget.state,
        relay: widget.relay,
      )));
      return;
    }

    // Navigate to meeting screen
    if (widget.state.meetingActive) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MeetingScreen(
        state: widget.state,
        relay: widget.relay,
        roomManager: widget.roomManager,
      ))).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: widget.state.localPlayer?.isAlive == true
            ? (d) {
                final size = MediaQuery.of(context).size;
                final dx = d.delta.dx / size.width;
                final dy = d.delta.dy / size.height;
                _game.moveLocalPlayer(dx, dy);
              }
            : null,
        onPanEnd: widget.state.localPlayer?.isAlive == true
            ? (_) => _game.stopLocalPlayer()
            : null,
        child: GameWidget<PhantomGame>(
          game: _game,
          overlayBuilderMap: {
            'hud': (context, game) => GameHudOverlay(game: game),
          },
        ),
      ),
    );
  }
}
