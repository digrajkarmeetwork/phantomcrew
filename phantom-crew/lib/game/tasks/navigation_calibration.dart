import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Navigation Calibration — Command Bridge
/// Rotate two dials to align with target values.
class NavigationCalibrationTask extends StatefulWidget {
  final VoidCallback onComplete;
  const NavigationCalibrationTask({super.key, required this.onComplete});

  @override
  State<NavigationCalibrationTask> createState() => _State();
}

class _State extends State<NavigationCalibrationTask> {
  // Two dials: X-axis and Y-axis alignment
  double _dial1 = 0.0;   // current
  double _dial2 = 0.0;
  final double _target1 = 0.73;
  final double _target2 = 0.41;
  static const double _tolerance = 0.05;
  bool _done = false;

  bool get _aligned =>
    (_dial1 - _target1).abs() < _tolerance &&
    (_dial2 - _target2).abs() < _tolerance;

  void _checkCompletion() {
    if (_aligned && !_done) {
      setState(() => _done = true);
      Future.delayed(const Duration(milliseconds: 600), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/tasks/navigation_calibration_bg.png', fit: BoxFit.cover),
        Container(color: Colors.black.withAlpha(170)),
        Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('ALIGN NAVIGATION GRID', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          const Text('Set both dials to the target values', style: TextStyle(color: PhantomTheme.textSecondary)),
          const SizedBox(height: 32),

          // Star map visual
          _StarMapDisplay(dial1: _dial1, dial2: _dial2, target1: _target1, target2: _target2),
          const SizedBox(height: 32),

          // Dial 1
          _DialControl(
            label: 'X-AXIS',
            value: _dial1,
            target: _target1,
            onChanged: (v) { setState(() => _dial1 = v); _checkCompletion(); },
          ),
          const SizedBox(height: 20),
          // Dial 2
          _DialControl(
            label: 'Y-AXIS',
            value: _dial2,
            target: _target2,
            onChanged: (v) { setState(() => _dial2 = v); _checkCompletion(); },
          ),

          const SizedBox(height: 24),
          if (_done)
            const Text('CALIBRATED', style: TextStyle(color: PhantomTheme.teal, fontFamily: 'Orbitron', fontSize: 18)),
        ],
      ),
        ),
      ],
    );
  }
}

class _StarMapDisplay extends StatelessWidget {
  final double dial1, dial2, target1, target2;
  const _StarMapDisplay({required this.dial1, required this.dial2, required this.target1, required this.target2});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200, height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF050C1A),
        shape: BoxShape.circle,
        border: Border.all(color: PhantomTheme.teal.withAlpha(80), width: 2),
      ),
      child: CustomPaint(painter: _StarMapPainter(dial1: dial1, dial2: dial2, target1: target1, target2: target2)),
    );
  }
}

class _StarMapPainter extends CustomPainter {
  final double dial1, dial2, target1, target2;
  _StarMapPainter({required this.dial1, required this.dial2, required this.target1, required this.target2});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Crosshair grid
    final gridPaint = Paint()..color = PhantomTheme.teal.withAlpha(30)..strokeWidth = 1;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), gridPaint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), gridPaint);

    // Target position (red dot)
    canvas.drawCircle(
      Offset(target1 * size.width, target2 * size.height),
      6,
      Paint()..color = PhantomTheme.red,
    );
    // Outer ring for target
    canvas.drawCircle(
      Offset(target1 * size.width, target2 * size.height),
      12,
      Paint()..color = PhantomTheme.red.withAlpha(60)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    // Current position (teal dot)
    canvas.drawCircle(
      Offset(dial1 * size.width, dial2 * size.height),
      5,
      Paint()..color = PhantomTheme.teal,
    );
  }

  @override
  bool shouldRepaint(covariant _StarMapPainter old) =>
    old.dial1 != dial1 || old.dial2 != dial2;
}

class _DialControl extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final ValueChanged<double> onChanged;
  const _DialControl({required this.label, required this.value, required this.target, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final aligned = (value - target).abs() < 0.05;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 12, letterSpacing: 1)),
          const Spacer(),
          Text(value.toStringAsFixed(2), style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 14,
            color: aligned ? PhantomTheme.teal : PhantomTheme.textPrimary,
          )),
          const SizedBox(width: 8),
          if (aligned) const Icon(Icons.check_circle, color: PhantomTheme.teal, size: 16),
        ]),
        Slider(
          value: value,
          min: 0, max: 1,
          activeColor: aligned ? PhantomTheme.teal : PhantomTheme.purple,
          inactiveColor: PhantomTheme.divider,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
