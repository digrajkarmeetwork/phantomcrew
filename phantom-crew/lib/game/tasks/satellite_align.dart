import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Satellite Align — Comms Array
/// Tap all lit satellites in the pattern shown, in order.
class SatelliteAlignTask extends StatefulWidget {
  final VoidCallback onComplete;
  const SatelliteAlignTask({super.key, required this.onComplete});

  @override
  State<SatelliteAlignTask> createState() => _State();
}

class _State extends State<SatelliteAlignTask> {
  static const List<int> _pattern = [0, 3, 1, 4, 2, 5];
  final List<bool> _tapped = List.filled(6, false);
  int _step = 0;
  bool _done = false;
  bool _error = false;

  void _tap(int idx) {
    if (_done || _error) return;
    if (_pattern[_step] == idx) {
      setState(() { _tapped[idx] = true; _step++; });
      if (_step == _pattern.length) {
        setState(() => _done = true);
        Future.delayed(const Duration(milliseconds: 600), widget.onComplete);
      }
    } else {
      setState(() => _error = true);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() {
          _error = false; _step = 0;
          for (int i = 0; i < 6; i++) _tapped[i] = false;
        });
      });
    }
  }

  static double _cos(double a) {
    const pi = 3.14159265358979;
    a = a % (2 * pi); double r = 1, t = 1;
    for (int i = 1; i <= 6; i++) { t *= -a * a / (2 * i * (2 * i - 1)); r += t; }
    return r;
  }
  static double _sin(double a) {
    const pi = 3.14159265358979;
    a = a % (2 * pi); double r = a, t = a;
    for (int i = 1; i <= 6; i++) { t *= -a * a / ((2 * i + 1) * (2 * i)); r += t; }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF08111E),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('SATELLITE ALIGN', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          Text(_done ? 'All satellites aligned!'
              : (_error ? 'Wrong sequence — resetting...' : 'Tap satellites in the correct sequence'),
            textAlign: TextAlign.center,
            style: TextStyle(color: _error ? PhantomTheme.red : PhantomTheme.textSecondary)),
          const SizedBox(height: 32),
          SizedBox(width: 280, height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: PhantomTheme.divider))),
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: PhantomTheme.teal.withAlpha(30), border: Border.all(color: PhantomTheme.teal, width: 2)),
                  child: const Icon(Icons.satellite_alt, color: PhantomTheme.teal, size: 18)),
                ...List.generate(6, (i) {
                  const r = 110.0, pi = 3.14159265358979;
                  final angle = (i / 6) * 2 * pi - pi / 2;
                  final x = 140 + r * _cos(angle), y = 140 + r * _sin(angle);
                  final isNext = !_done && !_error && _pattern[_step] == i;
                  return Positioned(
                    left: x - 24, top: y - 24,
                    child: _SatBtn(
                      label: (_pattern.indexOf(i) + 1).toString(),
                      tapped: _tapped[i], isNext: isNext, error: _error,
                      onTap: () => _tap(i),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_done && !_error)
            Text('Step ${_step + 1} of ${_pattern.length}', style: const TextStyle(color: PhantomTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _SatBtn extends StatelessWidget {
  final String label; final bool tapped, isNext, error; final VoidCallback onTap;
  const _SatBtn({required this.label, required this.tapped, required this.isNext, required this.error, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = tapped ? PhantomTheme.teal : (isNext ? Colors.amber : (error ? PhantomTheme.red : PhantomTheme.textSecondary));
    return GestureDetector(onTap: tapped ? null : onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        width: 48, height: 48,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.withAlpha(tapped ? 40 : 15),
          border: Border.all(color: c, width: isNext ? 2.5 : 1.5),
          boxShadow: isNext ? [BoxShadow(color: Colors.amber.withAlpha(100), blurRadius: 12)] : []),
        child: Center(child: Text(label, style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: c, fontWeight: FontWeight.bold)))));
  }
}
