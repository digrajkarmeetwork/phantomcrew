import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../network/relay_client.dart';
import '../network/room_manager.dart';
import 'game_screen.dart';

class RoleRevealScreen extends StatefulWidget {
  final GameState state;
  final RelayClient relay;
  final RoomManager roomManager;
  const RoleRevealScreen({super.key, required this.state, required this.relay, required this.roomManager});

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _scaleIn = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _animCtrl.forward();

    _navTimer = Timer(const Duration(seconds: 5), _proceed);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _navTimer?.cancel();
    super.dispose();
  }

  void _proceed() {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(
      state: widget.state,
      relay: widget.relay,
      roomManager: widget.roomManager,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final isPhantom = widget.state.isPhantom;

    final roleColor = isPhantom ? PhantomTheme.red : PhantomTheme.teal;
    final roleTitle = isPhantom ? 'PHANTOM AGENT' : 'GUARDIAN';
    final roleDesc = isPhantom
      ? 'You are infected by the Phantom.\nSabotage the station. Eliminate Guardians.\nDo not be discovered.'
      : 'You are an uninfected crew member.\nComplete all station protocols.\nFind and eject the Phantoms.';

    // List of phantom teammates (if phantom)
    final phantomMates = isPhantom
      ? widget.state.players.values.where((p) => p.isPhantom && p.id != widget.state.localPlayerId).toList()
      : <PlayerModel>[];

    return GestureDetector(
      onTap: _proceed,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                isPhantom
                  ? 'assets/images/ui/phantom_reveal.png'
                  : 'assets/images/ui/guardian_reveal.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(child: Container(color: Colors.black.withAlpha(130))),
            SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Role icon
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: roleColor.withAlpha(30),
                          border: Border.all(color: roleColor, width: 2),
                          boxShadow: [BoxShadow(color: roleColor.withAlpha(100), blurRadius: 30)],
                        ),
                        child: Icon(
                          isPhantom ? Icons.bug_report_outlined : Icons.shield_outlined,
                          color: roleColor,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'YOU ARE A',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(letterSpacing: 3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        roleTitle,
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                          shadows: [Shadow(color: roleColor.withAlpha(150), blurRadius: 20)],
                        ),
                      ),
                      const SizedBox(height: 20),
                      PhantomCard(
                        child: Text(
                          roleDesc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: PhantomTheme.textPrimary, height: 1.6),
                        ),
                      ),
                      if (phantomMates.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        PhantomCard(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('YOUR PHANTOM ALLIES:', style: TextStyle(color: PhantomTheme.red, fontSize: 12, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            ...phantomMates.map((p) => Row(children: [
                              Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(p.name, style: const TextStyle(color: PhantomTheme.textPrimary)),
                            ])),
                          ],
                        )),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        'Tap anywhere or wait 5 seconds...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
