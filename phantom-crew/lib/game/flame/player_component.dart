import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/player_model.dart';
import '../../ui/theme.dart';
import 'phantom_game.dart';

/// Animated player component with bob, sway, flip, glow ring, and name label.
class CrewPlayerComponent extends PositionComponent with HasGameReference<PhantomGame> {
  PlayerModel playerModel;
  final bool isLocalPlayer;

  // Sprite
  Sprite? _sprite;
  Sprite? _ghostSprite;
  bool _facingLeft = false;

  // Animation state
  double _bobPhase = 0;
  double _squashPhase = 0;
  String _lastAnimation = 'idle';

  // Smooth position interpolation for remote players
  Vector2 _targetPosition = Vector2.zero();

  static const double _spriteW = 48;
  static const double _spriteH = 56;

  CrewPlayerComponent({required this.playerModel, this.isLocalPlayer = false}) {
    size = Vector2(_spriteW, _spriteH);
    anchor = Anchor.center;
    _targetPosition = toWorld(playerModel.x, playerModel.y);
    position = _targetPosition.clone();
    // Randomise bob phase so players don't all bob in sync
    _bobPhase = (playerModel.id.hashCode % 100) / 100.0 * pi * 2;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprites();
  }

  Future<void> _loadSprites() async {
    try {
      final image = await game.images.load(
        'images/characters/guardian_idle_${playerModel.colorKey}.png',
      );
      _sprite = Sprite(image);
    } catch (_) {
      _sprite = null;
    }
    try {
      final ghostImage = await game.images.load('images/characters/guardian_ghost.png');
      _ghostSprite = Sprite(ghostImage);
    } catch (_) {
      _ghostSprite = null;
    }
  }

  void syncFromModel(PlayerModel model) {
    playerModel = model;
    _targetPosition = toWorld(model.x, model.y);

    // Update facing direction
    if (model.animation == 'walk_left') {
      _facingLeft = true;
    } else if (model.animation == 'walk_right') {
      _facingLeft = false;
    }
    _lastAnimation = model.animation;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Skip rendering if in vent and not local
    if (playerModel.inVent && !isLocalPlayer) return;

    // Smooth position interpolation
    if (isLocalPlayer) {
      // Local player: snap immediately
      position = _targetPosition.clone();
    } else {
      // Remote players: lerp for smooth movement
      position += (_targetPosition - position) * (dt * 12.0).clamp(0.0, 1.0);
    }

    // Animate bob
    _bobPhase += dt * (playerModel.animation.startsWith('walk') ? 8.0 : 2.5);
    _squashPhase += dt * 6.0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Don't render if in vent and not local phantom
    if (playerModel.inVent && !isLocalPlayer) return;
    // Don't render dead players (they become dead bodies on the map)
    if (playerModel.state == PlayerState.dead && !playerModel.isGhost) return;

    final isGhost = playerModel.isGhost;
    final isWalking = _lastAnimation.startsWith('walk');
    final color = playerModel.color;

    canvas.save();

    // Centre transform origin
    const cx = _spriteW / 2;
    const cy = _spriteH / 2;
    canvas.translate(cx, cy);

    // Ghost transparency
    if (isGhost) {
      final ghostAlpha = 0.3 + 0.15 * sin(_bobPhase * 0.5);
      canvas.saveLayer(
        Rect.fromCenter(center: Offset.zero, width: _spriteW * 2, height: _spriteH * 2),
        Paint()..color = Colors.white.withValues(alpha: ghostAlpha),
      );
    }

    // Walking squash/stretch
    double scaleX = 1.0;
    double scaleY = 1.0;
    if (isWalking) {
      scaleX = 1.0 + 0.04 * sin(_squashPhase);
      scaleY = 1.0 - 0.04 * sin(_squashPhase);
    }

    // Bob offset
    final bobY = sin(_bobPhase) * (isWalking ? 3.0 : 1.5);
    // Ghost float
    final floatY = isGhost ? sin(_bobPhase * 0.7) * 4.0 - 6.0 : 0.0;

    // Flip for direction
    if (_facingLeft) {
      canvas.scale(-scaleX, scaleY);
    } else {
      canvas.scale(scaleX, scaleY);
    }
    canvas.translate(0, bobY + floatY);

    // ── Draw glow ring under player ──
    _drawGlowRing(canvas, color, isGhost);

    // ── Draw sprite or fallback ──
    final drawRect = Rect.fromCenter(
      center: Offset.zero,
      width: _spriteW,
      height: _spriteH,
    );

    final sprite = isGhost ? (_ghostSprite ?? _sprite) : _sprite;
    if (sprite != null) {
      sprite.render(
        canvas,
        position: Vector2(drawRect.left, drawRect.top),
        size: Vector2(drawRect.width, drawRect.height),
      );
    } else {
      _drawFallbackCharacter(canvas, color, isGhost);
    }

    if (isGhost) {
      canvas.restore(); // restore ghost layer
    }

    canvas.restore();

    // ── Draw name label below player ──
    _drawNameLabel(canvas);
  }

  void _drawGlowRing(Canvas canvas, Color color, bool isGhost) {
    final glowColor = isGhost
        ? Colors.cyan.withAlpha(30)
        : color.withAlpha(50);
    // Outer glow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 20), width: 52, height: 18),
      Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Inner ring
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 20), width: 40, height: 14),
      Paint()
        ..color = color.withAlpha(isGhost ? 20 : 60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawFallbackCharacter(Canvas canvas, Color color, bool isGhost) {
    final bodyColor = isGhost ? Colors.cyan.withAlpha(80) : color;

    // Body (rounded rect)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 4), width: 28, height: 34),
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRect, Paint()..color = bodyColor);

    // Visor (dark slit on the face area)
    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(4, -4), width: 16, height: 8),
      const Radius.circular(3),
    );
    canvas.drawRRect(visorRect, Paint()..color = const Color(0xFF1A2A4A));
    // Visor glow
    canvas.drawRRect(
      visorRect,
      Paint()
        ..color = PhantomTheme.teal.withAlpha(isGhost ? 40 : 100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Legs
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-7, 24), width: 10, height: 14),
        const Radius.circular(4),
      ),
      Paint()..color = bodyColor.withAlpha(isGhost ? 50 : 200),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(7, 24), width: 10, height: 14),
        const Radius.circular(4),
      ),
      Paint()..color = bodyColor.withAlpha(isGhost ? 50 : 200),
    );

    // Backpack
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-16, 4), width: 8, height: 18),
        const Radius.circular(3),
      ),
      Paint()..color = bodyColor.withAlpha(isGhost ? 40 : 160),
    );
  }

  void _drawNameLabel(Canvas canvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: playerModel.name,
        style: TextStyle(
          color: isLocalPlayer
              ? PhantomTheme.teal
              : Colors.white.withAlpha(200),
          fontSize: 10,
          fontFamily: 'Exo2',
          fontWeight: isLocalPlayer ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Background pill
    final labelW = tp.width + 10;
    final labelH = tp.height + 4;
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(_spriteW / 2, _spriteH + 10),
        width: labelW,
        height: labelH,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(labelRect, Paint()..color = const Color(0xCC0A0A1A));

    tp.paint(canvas, Offset(
      _spriteW / 2 - tp.width / 2,
      _spriteH + 10 - tp.height / 2,
    ));
  }

  @override
  int get priority => playerModel.isGhost ? -1 : 10;
}
