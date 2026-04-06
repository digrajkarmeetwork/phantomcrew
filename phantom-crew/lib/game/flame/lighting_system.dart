import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../../ui/theme.dart';
import 'phantom_game.dart';

/// Renders player glow halos and blackout fog of war.
class LightingSystem extends PositionComponent with HasGameReference<PhantomGame> {
  final GameState state;
  bool isBlackout = false;

  // Cached player positions for lighting
  List<Vector2> _playerPositions = [];

  // Local player position for fog of war centre
  Vector2? _localPlayerPos;

  LightingSystem({required this.state});

  @override
  int get priority => 100; // Render on top of everything

  void updatePlayerPositions(List<Vector2> positions) {
    _playerPositions = positions;

    // Find local player position
    final localComp = game.playerComponents[state.localPlayerId];
    _localPlayerPos = localComp?.position;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (isBlackout) {
      _renderBlackoutFog(canvas);
    } else {
      _renderAmbientGlow(canvas);
    }
  }

  void _renderAmbientGlow(Canvas canvas) {
    // Subtle glow under each player
    for (final pos in _playerPositions) {
      final gradient = ui.Gradient.radial(
        Offset(pos.x, pos.y),
        80,
        [
          PhantomTheme.teal.withAlpha(15),
          PhantomTheme.teal.withAlpha(0),
        ],
      );
      canvas.drawCircle(
        Offset(pos.x, pos.y),
        80,
        Paint()..shader = gradient,
      );
    }
  }

  void _renderBlackoutFog(Canvas canvas) {
    if (_localPlayerPos == null) return;

    final cx = _localPlayerPos!.x;
    final cy = _localPlayerPos!.y;

    // Draw dark fog over the entire world with a cutout around the local player
    const fogAlpha = 220;
    const visRadius = 200.0; // Visibility radius in world pixels
    const softEdge = 60.0; // Gradient edge

    // Use a path with even-odd fill to cut a hole
    final path = Path()
      ..addRect(const Rect.fromLTWH(0, 0, kWorldScale, kWorldScale))
      ..addOval(Rect.fromCircle(
        center: Offset(cx, cy),
        radius: visRadius,
      ));
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = const Color.fromARGB(fogAlpha, 4, 8, 16),
    );

    // Soft gradient edge around visibility circle
    final edgeGradient = ui.Gradient.radial(
      Offset(cx, cy),
      visRadius + softEdge,
      [
        Colors.transparent,
        Colors.transparent,
        const Color.fromARGB(fogAlpha, 4, 8, 16),
      ],
      [0.0, visRadius / (visRadius + softEdge), 1.0],
    );
    canvas.drawCircle(
      Offset(cx, cy),
      visRadius + softEdge,
      Paint()..shader = edgeGradient,
    );

    // Flickering light effect (simulates emergency lighting)
    final flicker = 0.8 + 0.2 * sin(DateTime.now().millisecondsSinceEpoch / 200.0);
    final flickerGradient = ui.Gradient.radial(
      Offset(cx, cy),
      visRadius * flicker,
      [
        PhantomTheme.red.withAlpha(8),
        Colors.transparent,
      ],
    );
    canvas.drawCircle(
      Offset(cx, cy),
      visRadius * flicker,
      Paint()..shader = flickerGradient,
    );
  }
}
