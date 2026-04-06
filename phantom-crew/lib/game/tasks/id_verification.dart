import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// ID Verification — Command Bridge
/// Swipe the holographic ID card across the scanner from left to right.
class IdVerificationTask extends StatefulWidget {
  final VoidCallback onComplete;
  const IdVerificationTask({super.key, required this.onComplete});

  @override
  State<IdVerificationTask> createState() => _State();
}

class _State extends State<IdVerificationTask> with SingleTickerProviderStateMixin {
  double _cardX = 0.0;   // 0=left edge, 1=right edge
  bool _swiping = false;
  bool _success = false;
  bool _failed = false;
  late AnimationController _scanLine;

  @override
  void initState() {
    super.initState();
    _scanLine = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _scanLine.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d, double slotWidth) {
    if (_success) return;
    // Must start from left zone
    if (d.localPosition.dx < slotWidth * 0.2) {
      setState(() { _swiping = true; _failed = false; _cardX = 0.0; });
    }
  }

  void _onPanUpdate(DragUpdateDetails d, double slotWidth) {
    if (!_swiping || _success) return;
    setState(() {
      _cardX = (_cardX + d.delta.dx / slotWidth).clamp(0.0, 1.0);
    });
    // Must go right only — if reversed, fail
    if (d.delta.dx < -3) {
      setState(() { _swiping = false; _failed = true; _cardX = 0.0; });
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_swiping) return;
    if (_cardX >= 0.85) {
      setState(() { _success = true; _swiping = false; });
      Future.delayed(const Duration(milliseconds: 700), widget.onComplete);
    } else {
      setState(() { _swiping = false; _failed = true; _cardX = 0.0; });
      Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _failed = false);
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
          const Text('ID VERIFICATION', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          const Text('Swipe your ID card through the scanner →', style: TextStyle(color: PhantomTheme.textSecondary)),
          const SizedBox(height: 48),

          // Scanner slot
          LayoutBuilder(builder: (context, constraints) {
            final slotWidth = constraints.maxWidth;
            return GestureDetector(
              onPanStart: (d) => _onPanStart(d, slotWidth),
              onPanUpdate: (d) => _onPanUpdate(d, slotWidth),
              onPanEnd: _onPanEnd,
              child: _ScannerSlot(
                cardX: _cardX,
                success: _success,
                failed: _failed,
                scanLineAnim: _scanLine,
              ),
            );
          }),
          const SizedBox(height: 32),
          if (_success)
            const Text('ACCESS GRANTED', style: TextStyle(color: PhantomTheme.teal, fontFamily: 'Orbitron', fontSize: 18))
          else if (_failed)
            const Text('SWIPE FAILED — TRY AGAIN', style: TextStyle(color: PhantomTheme.red, fontFamily: 'Orbitron', fontSize: 13))
          else
            const Text('Start from the LEFT and swipe right', style: TextStyle(color: PhantomTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ScannerSlot extends StatelessWidget {
  final double cardX;
  final bool success;
  final bool failed;
  final AnimationController scanLineAnim;

  const _ScannerSlot({required this.cardX, required this.success, required this.failed, required this.scanLineAnim});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF050C1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: success ? PhantomTheme.teal : (failed ? PhantomTheme.red : PhantomTheme.divider),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Scan line
            AnimatedBuilder(
              animation: scanLineAnim,
              builder: (_, __) => Positioned(
                left: scanLineAnim.value * double.infinity,
                child: Container(),
              ),
            ),
            // Card
            Positioned(
              left: cardX == 0 ? 8 : null,
              right: cardX >= 0.99 ? 8 : null,
              top: 16, bottom: 16,
              child: Align(
                alignment: Alignment(cardX * 2 - 1, 0),
                child: _IdCard(success: success, failed: failed),
              ),
            ),
            // Direction arrow overlay
            if (!success && !failed)
              const Center(child: Icon(Icons.arrow_forward, color: PhantomTheme.textSecondary, size: 32)),
          ],
        ),
      ),
    );
  }
}

class _IdCard extends StatelessWidget {
  final bool success;
  final bool failed;
  const _IdCard({required this.success, required this.failed});

  @override
  Widget build(BuildContext context) {
    final color = success ? PhantomTheme.teal : (failed ? PhantomTheme.red : PhantomTheme.purple);
    return Container(
      width: 64, height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 8)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, color: color, size: 16),
          const SizedBox(height: 2),
          Text('CMC-ID', style: TextStyle(color: color, fontSize: 7, fontFamily: 'Orbitron')),
        ],
      ),
    );
  }
}
