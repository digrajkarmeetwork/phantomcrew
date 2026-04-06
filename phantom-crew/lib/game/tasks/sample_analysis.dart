import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Sample Analysis — Research Lab
/// Wait for the analysis bar to fill, then press Submit.
class SampleAnalysisTask extends StatefulWidget {
  final VoidCallback onComplete;
  const SampleAnalysisTask({super.key, required this.onComplete});

  @override
  State<SampleAnalysisTask> createState() => _State();
}

class _State extends State<SampleAnalysisTask> {
  double _progress = 0.0;
  bool _ready = false;
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_progress >= 1.0) {
        setState(() => _ready = true);
        _timer?.cancel();
      } else {
        setState(() => _progress += 0.008);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submit() {
    if (!_ready || _done) return;
    setState(() => _done = true);
    Future.delayed(const Duration(milliseconds: 500), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF08111E),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('SAMPLE ANALYSIS', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: PhantomTheme.teal)),
          const SizedBox(height: 8),
          Text(
            _ready ? 'Analysis complete — submit results' : 'Analysing quantum sample...',
            style: const TextStyle(color: PhantomTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Sample vial visual
          _SampleVial(progress: _progress),
          const SizedBox(height: 32),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 16,
              backgroundColor: PhantomTheme.divider,
              valueColor: AlwaysStoppedAnimation<Color>(_ready ? PhantomTheme.teal : PhantomTheme.purple),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toInt()}%',
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 20, color: PhantomTheme.textPrimary),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _ready && !_done ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _ready ? PhantomTheme.teal : PhantomTheme.divider,
              foregroundColor: PhantomTheme.darkBg,
            ),
            child: Text(_done ? 'SUBMITTED' : 'SUBMIT RESULTS'),
          ),
        ],
      ),
    );
  }
}

class _SampleVial extends StatelessWidget {
  final double progress;
  const _SampleVial({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60, height: 120,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        border: Border.all(color: PhantomTheme.teal.withAlpha(80), width: 2),
        color: const Color(0xFF050C1A),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 116 * progress,
            color: progress >= 1.0 ? PhantomTheme.teal : PhantomTheme.purple.withAlpha(180),
          ),
        ),
      ),
    );
  }
}
