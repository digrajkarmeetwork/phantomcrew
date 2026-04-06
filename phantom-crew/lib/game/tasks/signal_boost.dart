import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Signal Boost — Comms Array
/// Drag a frequency needle into the highlighted target zone on a dial.
class SignalBoostTask extends StatefulWidget {
  final VoidCallback onComplete;
  const SignalBoostTask({super.key, required this.onComplete});

  @override
  State<SignalBoostTask> createState() => _State();
}

class _State extends State<SignalBoostTask> {
  double _freq = 0.15;         // 0.0 to 1.0
  static const double _targetMin = 0.60;
  static const double _targetMax = 0.72;
  bool _done = false;

  bool get _inZone => _freq >= _targetMin && _freq <= _targetMax;

  void _check() {
    if (_inZone && !_done) {
      setState(() => _done = true);
      Future.delayed(const Duration(milliseconds: 800), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/tasks/signal_boost_bg.png', fit: BoxFit.cover),
        Container(color: Colors.black.withAlpha(170)),
        Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('SIGNAL BOOST', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          const Text('Tune the frequency needle into the target zone', style: TextStyle(color: PhantomTheme.textSecondary)),
          const SizedBox(height: 40),
          // Frequency dial
          SizedBox(width: 240, height: 240,
            child: CustomPaint(
              painter: _FreqDialPainter(freq: _freq, targetMin: _targetMin, targetMax: _targetMax, done: _done),
            ),
          ),
          const SizedBox(height: 32),
          Slider(
            value: _freq, min: 0, max: 1,
            activeColor: _inZone ? PhantomTheme.teal : PhantomTheme.purple,
            inactiveColor: PhantomTheme.divider,
            onChanged: (v) { setState(() => _freq = v); _check(); },
          ),
          Text(_inZone
              ? (_done ? 'SIGNAL LOCKED' : 'LOCKED — HOLD STEADY')
              : 'FREQUENCY: ${(_freq * 999 + 100).toStringAsFixed(1)} MHz',
            style: TextStyle(
              fontFamily: 'Orbitron', fontSize: 13,
              color: _inZone ? PhantomTheme.teal : PhantomTheme.textSecondary,
            ),
          ),
        ],
      ),
        ),
      ],
    );
  }
}

class _FreqDialPainter extends CustomPainter {
  final double freq, targetMin, targetMax;
  final bool done;
  _FreqDialPainter({required this.freq, required this.targetMin, required this.targetMax, required this.done});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.shortestSide / 2 - 8;

    // Background arc
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        _pi * 0.8, _pi * 1.4, false,
        Paint()..color = PhantomTheme.divider..style = PaintingStyle.stroke..strokeWidth = 16..strokeCap = StrokeCap.round);

    // Target zone (green arc)
    final zoneStart = _pi * 0.8 + targetMin * _pi * 1.4;
    final zoneSweep = (targetMax - targetMin) * _pi * 1.4;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        zoneStart, zoneSweep, false,
        Paint()..color = PhantomTheme.teal.withAlpha(done ? 255 : 120)..style = PaintingStyle.stroke..strokeWidth = 16..strokeCap = StrokeCap.round);

    // Needle
    final angle = _pi * 0.8 + freq * _pi * 1.4;
    final nx = cx + r * _cos(angle);
    final ny = cy + r * _sin(angle);
    final inZone = freq >= targetMin && freq <= targetMax;
    canvas.drawLine(Offset(cx, cy), Offset(nx, ny),
        Paint()..color = inZone ? PhantomTheme.teal : Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(nx, ny), 5, Paint()..color = inZone ? PhantomTheme.teal : Colors.orange);
  }

  static const double _pi = 3.14159265358979;
  double _cos(double a) {
    // Taylor approx
    a = a % (2 * _pi);
    double r = 1, t = 1;
    for (int i = 1; i <= 6; i++) { t *= -a * a / (2 * i * (2 * i - 1)); r += t; }
    return r;
  }
  double _sin(double a) {
    a = a % (2 * _pi);
    double r = a, t = a;
    for (int i = 1; i <= 6; i++) { t *= -a * a / ((2 * i + 1) * (2 * i)); r += t; }
    return r;
  }

  @override
  bool shouldRepaint(covariant _FreqDialPainter old) => old.freq != freq || old.done != done;
}
