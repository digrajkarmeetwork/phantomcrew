import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Power Routing — Engineering Bay
/// Connect coloured conduit nodes by tapping pairs in matching colours.
class PowerRoutingTask extends StatefulWidget {
  final VoidCallback onComplete;
  const PowerRoutingTask({super.key, required this.onComplete});

  @override
  State<PowerRoutingTask> createState() => _State();
}

class _State extends State<PowerRoutingTask> {
  // 4 colour pairs: left node index -> right node index
  static const _colors = [Colors.red, Colors.orange, PhantomTheme.teal, PhantomTheme.purple];
  // Shuffled right side order (which right index corresponds to which colour)
  final List<int> _rightOrder = [2, 0, 3, 1]; // teal, red, purple, orange
  final Set<int> _connected = {};
  int? _selected; // selected left node index
  bool _done = false;

  void _selectLeft(int i) {
    if (_connected.contains(i) || _done) return;
    setState(() => _selected = _selected == i ? null : i);
  }

  void _selectRight(int rightIdx) {
    if (_done) return;
    final left = _selected;
    if (left == null) return;
    // rightOrder[rightIdx] gives the colour index of this right node
    if (_rightOrder[rightIdx] == left) {
      setState(() {
        _connected.add(left);
        _selected = null;
      });
      if (_connected.length == 4) {
        setState(() => _done = true);
        Future.delayed(const Duration(milliseconds: 600), widget.onComplete);
      }
    } else {
      setState(() => _selected = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/tasks/power_routing_bg.png', fit: BoxFit.cover),
        Container(color: Colors.black.withAlpha(170)),
        Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('POWER ROUTING', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          const Text('Connect matching conduit nodes', style: TextStyle(color: PhantomTheme.textSecondary)),
          const SizedBox(height: 40),
          Row(
            children: [
              // Left nodes (ordered)
              Column(
                children: List.generate(4, (i) => _Node(
                  color: _colors[i],
                  label: ['A', 'B', 'C', 'D'][i],
                  selected: _selected == i,
                  connected: _connected.contains(i),
                  onTap: () => _selectLeft(i),
                )),
              ),
              // Wire canvas
              Expanded(child: SizedBox(
                height: 240,
                child: CustomPaint(painter: _WirePainter(
                  connected: _connected,
                  rightOrder: _rightOrder,
                  colors: _colors,
                  selected: _selected,
                )),
              )),
              // Right nodes (shuffled)
              Column(
                children: List.generate(4, (i) {
                  final colorIdx = _rightOrder[i];
                  return _Node(
                    color: _colors[colorIdx],
                    label: ['A', 'B', 'C', 'D'][colorIdx],
                    selected: false,
                    connected: _connected.contains(colorIdx),
                    onTap: () => _selectRight(i),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_done)
            const Text('ROUTING COMPLETE', style: TextStyle(color: PhantomTheme.teal, fontFamily: 'Orbitron', fontSize: 16))
          else
            Text('Connected: ${_connected.length}/4', style: const TextStyle(color: PhantomTheme.textSecondary)),
        ],
      ),
        ),
      ],
    );
  }
}

class _Node extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;
  const _Node({required this.color, required this.label, required this.selected, required this.connected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: connected ? color.withAlpha(80) : (selected ? color.withAlpha(50) : color.withAlpha(20)),
          border: Border.all(
            color: color,
            width: selected ? 3 : 2,
          ),
          boxShadow: selected || connected ? [BoxShadow(color: color.withAlpha(120), blurRadius: 10)] : [],
        ),
        child: Center(child: Text(label, style: TextStyle(color: color, fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold))),
      ),
    );
  }
}

class _WirePainter extends CustomPainter {
  final Set<int> connected;
  final List<int> rightOrder;
  final List<Color> colors;
  final int? selected;
  _WirePainter({required this.connected, required this.rightOrder, required this.colors, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    const nodeCount = 4;
    final spacing = size.height / nodeCount;
    final midY = spacing / 2;

    for (int i = 0; i < nodeCount; i++) {
      if (!connected.contains(i)) continue;
      // Find which right index this left node connects to
      final rightIdx = rightOrder.indexOf(i);
      final ly = midY + i * spacing;
      final ry = midY + rightIdx * spacing;
      final paint = Paint()
        ..color = colors[i].withAlpha(200)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(0, ly)
        ..cubicTo(size.width * 0.3, ly, size.width * 0.7, ry, size.width, ry);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WirePainter old) => true;
}
