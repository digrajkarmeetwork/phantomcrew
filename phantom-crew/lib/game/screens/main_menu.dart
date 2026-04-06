import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../ui/theme.dart';
import '../models/game_state.dart';
import '../network/relay_client.dart';
import 'create_room.dart';
import 'join_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const MainMenuScreen({super.key, required this.prefs});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with SingleTickerProviderStateMixin {
  late final TextEditingController _nameCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    final savedName = widget.prefs.getString('playerName') ?? '';
    _nameCtrl = TextEditingController(text: savedName);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _playerName => _nameCtrl.text.trim();
  bool get _nameValid => _playerName.isNotEmpty && _playerName.length <= 16;

  void _saveName() => widget.prefs.setString('playerName', _playerName);

  void _goToCreate() {
    if (!_nameValid) return;
    _saveName();
    final state = _buildState();
    final relay = _buildRelay();
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRoomScreen(
      state: state,
      relay: relay,
    )));
  }

  void _goToJoin() {
    if (!_nameValid) return;
    _saveName();
    final state = _buildState();
    final relay = _buildRelay();
    Navigator.push(context, MaterialPageRoute(builder: (_) => JoinScreen(
      state: state,
      relay: relay,
    )));
  }

  GameState _buildState() {
    final playerId = widget.prefs.getString('playerId') ?? const Uuid().v4();
    widget.prefs.setString('playerId', playerId);
    final gs = GameState()
      ..localPlayerId = playerId
      ..localPlayerName = _playerName
      ..localPlayerColor = widget.prefs.getString('playerColor') ?? 'cyan';
    return gs;
  }

  RelayClient _buildRelay() {
    final url = widget.prefs.getString('relayUrl') ?? RelayClient.defaultRelayUrl;
    return RelayClient(relayUrl: url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [Color(0xFF0D1F3C), PhantomTheme.darkBg],
              ),
            ),
          ),
          // Starfield effect (simple dots)
          const _Starfield(),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Logo
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: Column(
                        children: [
                          GlowText('PHANTOM', fontSize: 42),
                          GlowText('CREW', fontSize: 42, color: PhantomTheme.purple),
                          const SizedBox(height: 8),
                          Text(
                            'Trust no one. The phantom is already among you.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Name input
                  TextField(
                    controller: _nameCtrl,
                    maxLength: 16,
                    decoration: const InputDecoration(
                      labelText: 'YOUR NAME',
                      hintText: 'Enter crew name...',
                      counterText: '',
                      prefixIcon: Icon(Icons.person_outline, color: PhantomTheme.teal),
                    ),
                    style: const TextStyle(color: PhantomTheme.textPrimary, fontSize: 16),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _nameValid ? _goToCreate : null,
                    child: const Text('CREATE ROOM'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _nameValid ? _goToJoin : null,
                    child: const Text('JOIN ROOM'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SettingsScreen(prefs: widget.prefs)),
                    ),
                    child: const Text('SETTINGS', style: TextStyle(color: PhantomTheme.textSecondary)),
                  ),
                  const Spacer(),
                  Text(
                    'v1.0.0 — CMC HORIZON STATION',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Starfield extends StatelessWidget {
  const _Starfield();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter());
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final stars = [
      Offset(0.1, 0.05), Offset(0.3, 0.12), Offset(0.7, 0.08), Offset(0.9, 0.2),
      Offset(0.15, 0.3), Offset(0.5, 0.25), Offset(0.8, 0.35), Offset(0.25, 0.5),
      Offset(0.6, 0.45), Offset(0.95, 0.55), Offset(0.05, 0.65), Offset(0.4, 0.7),
      Offset(0.75, 0.6), Offset(0.2, 0.8), Offset(0.55, 0.85), Offset(0.85, 0.75),
      Offset(0.35, 0.9), Offset(0.65, 0.95), Offset(0.45, 0.15), Offset(0.12, 0.42),
    ];
    for (final s in stars) {
      paint.color = Colors.white.withAlpha(((0.3 + (s.dx * 0.7)) * 255).toInt());
      canvas.drawCircle(Offset(s.dx * size.width, s.dy * size.height), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
