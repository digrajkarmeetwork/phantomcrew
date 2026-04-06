import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Air Scrubber Maintenance — Life Support
/// Tap the glowing filter panels in the correct sequence to clean them.
class AirScrubberTask extends StatefulWidget {
  final VoidCallback onComplete;
  const AirScrubberTask({super.key, required this.onComplete});

  @override
  State<AirScrubberTask> createState() => _State();
}

class _State extends State<AirScrubberTask> {
  // 3x3 grid of panels. Dirty = needs cleaning.
  final List<bool> _dirty = List.generate(9, (i) => i != 4); // centre always clean
  final List<bool> _cleaned = List.filled(9, false);
  bool _done = false;

  int get _remaining => _dirty.where((d) => d).length -
      List.generate(9, (i) => _dirty[i] && _cleaned[i]).where((b) => b).length;

  void _tap(int i) {
    if (!_dirty[i] || _cleaned[i] || _done) return;
    setState(() => _cleaned[i] = true);
    if (_remaining == 0) {
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
          const Text('AIR SCRUBBER', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          Text(_done ? 'All filters clean!' : 'Tap all dirty filter panels to clean them',
              style: const TextStyle(color: PhantomTheme.textSecondary)),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(9, (i) => _FilterPanel(
              dirty: _dirty[i],
              cleaned: _cleaned[i],
              onTap: () => _tap(i),
            )),
          ),
          const SizedBox(height: 24),
          if (!_done)
            Text('$_remaining panel${_remaining == 1 ? "" : "s"} remaining',
                style: const TextStyle(color: PhantomTheme.textSecondary))
          else
            const Text('SCRUBBER ONLINE', style: TextStyle(color: PhantomTheme.teal, fontFamily: 'Orbitron')),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final bool dirty;
  final bool cleaned;
  final VoidCallback onTap;
  const _FilterPanel({required this.dirty, required this.cleaned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg, border;
    IconData icon;
    if (!dirty) {
      bg = PhantomTheme.teal.withAlpha(15); border = PhantomTheme.divider; icon = Icons.check;
    } else if (cleaned) {
      bg = PhantomTheme.teal.withAlpha(30); border = PhantomTheme.teal; icon = Icons.check_circle;
    } else {
      bg = Colors.orange.withAlpha(20); border = Colors.orange; icon = Icons.warning_amber;
    }
    return GestureDetector(
      onTap: dirty && !cleaned ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Icon(icon, color: border, size: 28),
      ),
    );
  }
}
