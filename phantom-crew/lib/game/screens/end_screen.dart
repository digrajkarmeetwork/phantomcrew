import 'package:flutter/material.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import '../network/relay_client.dart';
import 'main_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EndScreen extends StatefulWidget {
  final GameState state;
  final RelayClient relay;
  const EndScreen({super.key, required this.state, required this.relay});

  @override
  State<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<EndScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
    widget.relay.dispose();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  bool get _guardiansWin {
    final wc = widget.state.room?.winCondition;
    return wc == WinCondition.guardiansTasksComplete || wc == WinCondition.guardiansEliminatedPhantoms;
  }

  String get _winTitle {
    switch (widget.state.room?.winCondition) {
      case WinCondition.guardiansTasksComplete:
        return 'STATION SECURED';
      case WinCondition.guardiansEliminatedPhantoms:
        return 'PHANTOMS PURGED';
      case WinCondition.phantomsOutnumber:
        return 'RIFT OPENED';
      case WinCondition.phantomsCascade:
        return 'STATION LOST';
      default:
        return 'GAME OVER';
    }
  }

  String get _winSubtitle {
    switch (widget.state.room?.winCondition) {
      case WinCondition.guardiansTasksComplete:
        return 'All station protocols completed.\nGuardians win!';
      case WinCondition.guardiansEliminatedPhantoms:
        return 'All Phantom Agents ejected.\nGuardians win!';
      case WinCondition.phantomsOutnumber:
        return 'The Phantom Agents outnumber the crew.\nPhantom Crew wins!';
      case WinCondition.phantomsCascade:
        return 'Reactor Cascade completed.\nPhantom Crew wins!';
      default:
        return '';
    }
  }

  void _returnToMenu() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainMenuScreen(prefs: prefs)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final guardiansWin = _guardiansWin;
    final titleColor = guardiansWin ? PhantomTheme.teal : PhantomTheme.red;
    final allPlayers = widget.state.players.values.toList();
    final phantoms = allPlayers.where((p) => p.isPhantom).toList();
    final guardians = allPlayers.where((p) => !p.isPhantom).toList();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              guardiansWin
                ? 'assets/images/ui/guardians_win.png'
                : 'assets/images/ui/phantoms_win.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withAlpha(160))),
          SafeArea(child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Icon(
                    guardiansWin ? Icons.shield : Icons.warning_amber,
                    color: titleColor,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(_winTitle, style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    shadows: [Shadow(color: titleColor.withAlpha(150), blurRadius: 20)],
                  )),
                  const SizedBox(height: 8),
                  Text(_winSubtitle, textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                  const SizedBox(height: 32),

                  // Phantom reveal
                  PhantomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PHANTOM AGENTS WERE:',
                          style: TextStyle(color: PhantomTheme.red, fontSize: 12, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        ...phantoms.map((p) => _PlayerRevealRow(player: p, isPhantom: true)),
                        const Divider(color: PhantomTheme.divider, height: 24),
                        const Text('GUARDIANS:',
                          style: TextStyle(color: PhantomTheme.teal, fontSize: 12, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        ...guardians.map((p) => _PlayerRevealRow(player: p, isPhantom: false)),
                      ],
                    ),
                  ),

                  const Spacer(),
                  ElevatedButton(
                    onPressed: _returnToMenu,
                    child: const Text('RETURN TO BASE'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _PlayerRevealRow extends StatelessWidget {
  final PlayerModel player;
  final bool isPhantom;
  const _PlayerRevealRow({required this.player, required this.isPhantom});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 20, height: 20, decoration: BoxDecoration(color: player.color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(player.name, style: const TextStyle(color: PhantomTheme.textPrimary, fontSize: 14)),
          const Spacer(),
          if (player.state == PlayerState.dead || player.state == PlayerState.ghost)
            const Text('EJECTED', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
