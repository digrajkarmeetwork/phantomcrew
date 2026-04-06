import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ui/theme.dart';
import '../network/relay_client.dart';

class SettingsScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const SettingsScreen({super.key, required this.prefs});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _relayCtrl;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _relayCtrl = TextEditingController(
      text: widget.prefs.getString('relayUrl') ?? RelayClient.defaultRelayUrl,
    );
    _selectedColor = widget.prefs.getString('playerColor') ?? 'cyan';
  }

  @override
  void dispose() {
    _relayCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.prefs.setString('relayUrl', _relayCtrl.text.trim());
    widget.prefs.setString('playerColor', _selectedColor);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved'), duration: Duration(seconds: 1)),
    );
    Navigator.pop(context);
  }

  void _reset() {
    _relayCtrl.text = RelayClient.defaultRelayUrl;
  }

  @override
  Widget build(BuildContext context) {
    const colors = PhantomTheme.playerColors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: PhantomTheme.teal),
        title: const Text('SETTINGS', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DEFAULT SUIT COLOUR', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: colors.entries.map((e) => GestureDetector(
                onTap: () => setState(() => _selectedColor = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColor == e.key ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),
            const Text('RELAY SERVER URL', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: _relayCtrl,
              decoration: InputDecoration(
                hintText: 'wss://...',
                prefixIcon: const Icon(Icons.lan_outlined, color: PhantomTheme.teal),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh, color: PhantomTheme.textSecondary),
                  onPressed: _reset,
                  tooltip: 'Reset to default',
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Text(
              'Default: ${RelayClient.defaultRelayUrl}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
            ),
            const Spacer(),
            ElevatedButton(onPressed: _save, child: const Text('SAVE SETTINGS')),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
