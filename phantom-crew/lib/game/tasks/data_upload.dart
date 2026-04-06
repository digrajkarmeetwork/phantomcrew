import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Data Upload — Research Lab
/// Hold the upload button until the progress reaches 100%.
/// Releasing early resets progress.
class DataUploadTask extends StatefulWidget {
  final VoidCallback onComplete;
  const DataUploadTask({super.key, required this.onComplete});

  @override
  State<DataUploadTask> createState() => _State();
}

class _State extends State<DataUploadTask> {
  double _progress = 0.0;
  bool _holding = false;
  bool _done = false;
  Timer? _timer;

  void _startHold() {
    if (_done) return;
    setState(() => _holding = true);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_holding) { _timer?.cancel(); return; }
      setState(() => _progress = (_progress + 0.015).clamp(0.0, 1.0));
      if (_progress >= 1.0) {
        _timer?.cancel();
        setState(() { _done = true; _holding = false; });
        Future.delayed(const Duration(milliseconds: 400), widget.onComplete);
      }
    });
  }

  void _endHold() {
    _timer?.cancel();
    if (_done) return;
    setState(() { _holding = false; _progress = 0.0; });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF08111E),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('DATA UPLOAD', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          const Text('Hold the upload button to transfer data\nReleasing will reset progress', textAlign: TextAlign.center,
              style: TextStyle(color: PhantomTheme.textSecondary)),
          const SizedBox(height: 40),
          // Upload icon with glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_holding ? PhantomTheme.teal : PhantomTheme.divider).withAlpha(20),
              border: Border.all(color: _holding ? PhantomTheme.teal : PhantomTheme.divider, width: 2),
              boxShadow: _holding ? [BoxShadow(color: PhantomTheme.teal.withAlpha(100), blurRadius: 24)] : [],
            ),
            child: Icon(Icons.upload_rounded, size: 56,
                color: _holding ? PhantomTheme.teal : PhantomTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          // Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress, minHeight: 16,
              backgroundColor: PhantomTheme.divider,
              valueColor: AlwaysStoppedAnimation<Color>(_done ? PhantomTheme.teal : PhantomTheme.purple),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toInt()}%',
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 20, color: PhantomTheme.textPrimary)),
          const SizedBox(height: 32),
          GestureDetector(
            onTapDown: (_) => _startHold(),
            onTapUp: (_) => _endHold(),
            onTapCancel: _endHold,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _done ? PhantomTheme.teal.withAlpha(40)
                    : (_holding ? PhantomTheme.teal.withAlpha(30) : PhantomTheme.cardBg),
                border: Border.all(color: _done ? PhantomTheme.teal : (_holding ? PhantomTheme.teal : PhantomTheme.divider), width: 2),
              ),
              child: Text(
                _done ? 'UPLOAD COMPLETE' : (_holding ? 'UPLOADING...' : 'HOLD TO UPLOAD'),
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                    color: _holding || _done ? PhantomTheme.teal : PhantomTheme.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
