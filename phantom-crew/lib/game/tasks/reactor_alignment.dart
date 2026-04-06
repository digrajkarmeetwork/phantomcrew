import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Reactor Alignment — Engineering Bay
/// Match 3 frequency sliders to target values within tolerance.
class ReactorAlignmentTask extends StatefulWidget {
  final VoidCallback onComplete;
  const ReactorAlignmentTask({super.key, required this.onComplete});

  @override
  State<ReactorAlignmentTask> createState() => _State();
}

class _State extends State<ReactorAlignmentTask> {
  final List<double> _values = [0.2, 0.6, 0.45];
  final List<double> _targets = [0.68, 0.32, 0.77];
  static const double _tolerance = 0.04;
  bool _done = false;

  bool get _allAligned => List.generate(3, (i) => (_values[i] - _targets[i]).abs() < _tolerance).every((b) => b);

  void _check() {
    if (_allAligned && !_done) {
      setState(() => _done = true);
      Future.delayed(const Duration(milliseconds: 600), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF08111E),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('REACTOR ALIGNMENT', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          const Text('Match all frequency sliders to target values', style: TextStyle(color: PhantomTheme.textSecondary)),
          const SizedBox(height: 32),

          // Oscilloscope display
          _OscilloscopeDisplay(values: _values, targets: _targets),
          const SizedBox(height: 32),

          // Sliders
          for (int i = 0; i < 3; i++) ...[
            _FrequencySlider(
              label: ['ALPHA', 'BETA', 'GAMMA'][i],
              value: _values[i],
              target: _targets[i],
              onChanged: (v) { setState(() => _values[i] = v); _check(); },
            ),
            const SizedBox(height: 16),
          ],

          if (_done)
            const Text('ALIGNED', style: TextStyle(color: PhantomTheme.teal, fontFamily: 'Orbitron', fontSize: 18)),
        ],
      ),
    );
  }
}

class _OscilloscopeDisplay extends StatelessWidget {
  final List<double> values;
  final List<double> targets;
  const _OscilloscopeDisplay({required this.values, required this.targets});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF050C1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PhantomTheme.teal.withAlpha(60)),
      ),
      child: CustomPaint(painter: _OscPainter(values: values, targets: targets)),
    );
  }
}

class _OscPainter extends CustomPainter {
  final List<double> values;
  final List<double> targets;
  _OscPainter({required this.values, required this.targets});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [PhantomTheme.teal, Colors.orange, PhantomTheme.purple];
    for (int i = 0; i < 3; i++) {
      final paint = Paint()..color = colors[i].withAlpha(180)..strokeWidth = 1.5;
      final targetPaint = Paint()..color = colors[i].withAlpha(60)..strokeWidth = 1..style = PaintingStyle.stroke;

      // Draw sine-like wave for this frequency
      final path = Path();
      for (int x = 0; x <= size.width.toInt(); x++) {
        final t = x / size.width;
        final freq = 3 + values[i] * 5;
        final y = size.height / 2 + (size.height * 0.3) * (1 - values[i]) *
          (i == 0 ? 1 : (i == 1 ? -1 : 0.5)) *
          _sin(t * freq * 2 * 3.14159);
        if (x == 0) path.moveTo(x.toDouble(), y); else path.lineTo(x.toDouble(), y);
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);

      // Target line (dashed)
      final ty = size.height * (1 - targets[i]);
      canvas.drawLine(Offset(0, ty), Offset(size.width, ty), targetPaint);
    }
  }

  double _sin(double x) => x.isNaN ? 0 : _approxSin(x);
  double _approxSin(double x) {
    x = x % (2 * 3.14159);
    if (x < 0) x += 2 * 3.14159;
    return (x < 3.14159 ? 1 : -1) * (x.abs() < 1.5708 ? x.abs() / 1.5708 : (3.14159 - x.abs()) / 1.5708);
  }

  @override
  bool shouldRepaint(covariant _OscPainter old) => true;
}

class _FrequencySlider extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final ValueChanged<double> onChanged;
  const _FrequencySlider({required this.label, required this.value, required this.target, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final aligned = (value - target).abs() < 0.04;
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label, style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 11, letterSpacing: 1))),
        Expanded(child: Slider(
          value: value,
          min: 0, max: 1,
          activeColor: aligned ? PhantomTheme.teal : PhantomTheme.purple,
          inactiveColor: PhantomTheme.divider,
          onChanged: onChanged,
        )),
        SizedBox(width: 32, child: aligned
          ? const Icon(Icons.check, color: PhantomTheme.teal, size: 18)
          : Text(value.toStringAsFixed(2), style: const TextStyle(color: PhantomTheme.textSecondary, fontSize: 11))),
      ],
    );
  }
}
