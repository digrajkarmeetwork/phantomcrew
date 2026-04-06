import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Filter Replace — Life Support
/// Insert filter cartridges into slots in the correct numbered order (1→4).
class FilterReplaceTask extends StatefulWidget {
  final VoidCallback onComplete;
  const FilterReplaceTask({super.key, required this.onComplete});

  @override
  State<FilterReplaceTask> createState() => _State();
}

class _State extends State<FilterReplaceTask> {
  // 4 filters shown in random visual order; player must tap them 1,2,3,4
  final List<int> _slotOrder = [3, 1, 4, 2]; // visual position -> filter number
  final List<bool> _inserted = List.filled(4, false);
  int _nextExpected = 1; // 1-indexed
  bool _done = false;
  int? _wrongTap;

  void _tap(int slotIdx) {
    if (_done) return;
    final filterNum = _slotOrder[slotIdx];
    if (filterNum == _nextExpected) {
      setState(() {
        _inserted[slotIdx] = true;
        _nextExpected++;
        _wrongTap = null;
      });
      if (_nextExpected > 4) {
        setState(() => _done = true);
        Future.delayed(const Duration(milliseconds: 600), widget.onComplete);
      }
    } else {
      setState(() => _wrongTap = slotIdx);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongTap = null);
      });
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
          const Text('FILTER REPLACE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          Text(_done ? 'All filters installed!' : 'Insert filters in order: 1 → 2 → 3 → 4',
              textAlign: TextAlign.center, style: const TextStyle(color: PhantomTheme.textSecondary)),
          const SizedBox(height: 32),
          // Filter housing unit
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF050C1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PhantomTheme.divider, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (i) => _FilterSlot(
                filterNum: _slotOrder[i],
                inserted: _inserted[i],
                isWrong: _wrongTap == i,
                onTap: () => _tap(i),
              )),
            ),
          ),
          const SizedBox(height: 32),
          if (!_done) ...[
            Text('Next: Filter #$_nextExpected',
                style: const TextStyle(color: Colors.amber, fontFamily: 'Orbitron', fontSize: 16)),
          ] else
            const Text('LIFE SUPPORT RESTORED', style: TextStyle(color: PhantomTheme.teal, fontFamily: 'Orbitron')),
        ],
      ),
    );
  }
}

class _FilterSlot extends StatelessWidget {
  final int filterNum;
  final bool inserted;
  final bool isWrong;
  final VoidCallback onTap;
  const _FilterSlot({required this.filterNum, required this.inserted, required this.isWrong, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = inserted ? PhantomTheme.teal : (isWrong ? PhantomTheme.red : PhantomTheme.textSecondary);
    return GestureDetector(
      onTap: inserted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64, height: 100,
        decoration: BoxDecoration(
          color: color.withAlpha(inserted ? 25 : 15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
          boxShadow: inserted ? [BoxShadow(color: PhantomTheme.teal.withAlpha(80), blurRadius: 10)] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(inserted ? Icons.check_circle : Icons.filter_alt_outlined, color: color, size: 28),
            const SizedBox(height: 6),
            Text('#$filterNum', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }
}
