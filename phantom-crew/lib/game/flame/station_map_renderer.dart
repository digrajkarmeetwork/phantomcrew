import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/station_map.dart';
import '../../ui/theme.dart';
import 'phantom_game.dart';

/// Renders the station map using a full pre-rendered background image
/// with interactive overlay elements (vents, task zones, labels, etc.).
class StationMapRenderer extends PositionComponent with HasGameReference<PhantomGame> {
  // Full station map background
  Sprite? _mapBackground;

  // Overlay sprites
  Sprite? _ventClosed;
  Sprite? _taskIcon;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2.all(kWorldScale);
    position = Vector2.zero();

    // Load the full map background
    _mapBackground = await _loadSprite('images/map/station_map_full.png');

    // Load overlay sprites
    _ventClosed = await _loadSprite('images/map/vent_grate_closed.png');
    _taskIcon = await _loadSprite('images/map/task_station_icon.png');
  }

  Future<Sprite?> _loadSprite(String path) async {
    try {
      final image = await game.images.load(path);
      return Sprite(image);
    } catch (_) {
      return null;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw space background (visible around station edges)
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kWorldScale, kWorldScale),
      Paint()..color = const Color(0xFF040810),
    );

    // Draw the full station map image
    if (_mapBackground != null) {
      _mapBackground!.render(
        canvas,
        position: Vector2.zero(),
        size: Vector2.all(kWorldScale),
      );
    } else {
      // Fallback: draw rooms as filled rects
      _drawFallbackMap(canvas);
    }

    // Draw room labels
    _drawRoomLabels(canvas);

    // Draw vent grates
    _drawVents(canvas);

    // Draw task zone indicators
    _drawTaskZones(canvas);

    // Draw sabotage fix panels
    _drawFixPanels(canvas);

    // Draw sealed zone overlay
    _drawSealedZone(canvas);

    // Draw dead bodies
    _drawDeadBodies(canvas);
  }

  void _drawFallbackMap(Canvas canvas) {
    // Draw corridors
    for (final corridor in StationMap.corridors) {
      final pixelRect = Rect.fromLTWH(
        corridor.left * kWorldScale,
        corridor.top * kWorldScale,
        corridor.width * kWorldScale,
        corridor.height * kWorldScale,
      );
      canvas.drawRect(pixelRect, Paint()..color = const Color(0xFF111827));
    }
    // Draw rooms
    for (final room in StationMap.rooms.values) {
      final pixelRect = Rect.fromLTWH(
        room.left * kWorldScale,
        room.top * kWorldScale,
        room.width * kWorldScale,
        room.height * kWorldScale,
      );
      canvas.drawRect(pixelRect, Paint()..color = const Color(0xFF0D1520));
      canvas.drawRect(
        pixelRect,
        Paint()
          ..color = const Color(0xFF1E2D45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawRoomLabels(Canvas canvas) {
    for (final entry in StationMap.rooms.entries) {
      final r = entry.value;
      final cx = r.center.dx * kWorldScale;
      final cy = r.top * kWorldScale + 24;

      // Label background for readability
      final tp = TextPainter(
        text: TextSpan(
          text: entry.key.toUpperCase(),
          style: TextStyle(
            color: const Color(0xFF8AC8E8).withAlpha(220),
            fontSize: 13,
            fontFamily: 'Orbitron',
            letterSpacing: 2,
            shadows: const [
              Shadow(color: Color(0xFF000000), blurRadius: 6),
              Shadow(color: Color(0xFF000000), blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy));
    }
  }

  void _drawVents(Canvas canvas) {
    for (final entry in StationMap.ventPositions.entries) {
      final pos = entry.value;
      final wx = pos.dx * kWorldScale;
      final wy = pos.dy * kWorldScale;
      final ventSize = Vector2(48, 34);

      if (_ventClosed != null) {
        _ventClosed!.render(
          canvas,
          position: Vector2(wx - ventSize.x / 2, wy - ventSize.y / 2),
          size: ventSize,
        );
      } else {
        // Fallback vent
        final rect = Rect.fromCenter(
          center: Offset(wx, wy),
          width: 48,
          height: 34,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = PhantomTheme.purple.withAlpha(60),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..color = PhantomTheme.purple.withAlpha(150)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        // Grate lines
        for (int i = -1; i <= 1; i++) {
          canvas.drawLine(
            Offset(wx - 16, wy + i * 8.0),
            Offset(wx + 16, wy + i * 8.0),
            Paint()
              ..color = PhantomTheme.purple.withAlpha(100)
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  void _drawTaskZones(Canvas canvas) {
    for (final zone in StationMap.taskZones.values) {
      final wx = zone.dx * kWorldScale;
      final wy = zone.dy * kWorldScale;

      if (_taskIcon != null) {
        _taskIcon!.render(
          canvas,
          position: Vector2(wx - 18, wy - 18),
          size: Vector2.all(36),
        );
      }

      // Pulsing outer glow ring
      canvas.drawCircle(
        Offset(wx, wy),
        22,
        Paint()
          ..color = PhantomTheme.teal.withAlpha(25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Inner dot
      canvas.drawCircle(
        Offset(wx, wy),
        5,
        Paint()..color = PhantomTheme.teal.withAlpha(200),
      );
      // Ring
      canvas.drawCircle(
        Offset(wx, wy),
        14,
        Paint()
          ..color = PhantomTheme.teal.withAlpha(100)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawFixPanels(Canvas canvas) {
    final room = game.state.room;
    if (room == null || !room.hasSabotage) return;

    final sabType = room.activeSabotage.name;
    final panels = StationMap.fixPanels[sabType] ?? {};

    for (final entry in panels.entries) {
      final wx = entry.value.dx * kWorldScale;
      final wy = entry.value.dy * kWorldScale;

      // Pulsing outer ring
      canvas.drawCircle(
        Offset(wx, wy), 26,
        Paint()
          ..color = PhantomTheme.red.withAlpha(40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Inner marker
      canvas.drawCircle(
        Offset(wx, wy), 14,
        Paint()..color = PhantomTheme.red.withAlpha(180),
      );
      // Exclamation
      canvas.drawLine(
        Offset(wx, wy - 6), Offset(wx, wy + 2),
        Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(wx, wy + 7), 2.5, Paint()..color = Colors.white);
    }
  }

  void _drawSealedZone(Canvas canvas) {
    final sealedZone = game.state.room?.sealedZone;
    if (sealedZone == null) return;

    final sealedRect = StationMap.rooms[sealedZone];
    if (sealedRect == null) return;

    final pixelRect = Rect.fromLTWH(
      sealedRect.left * kWorldScale,
      sealedRect.top * kWorldScale,
      sealedRect.width * kWorldScale,
      sealedRect.height * kWorldScale,
    );

    canvas.drawRect(pixelRect, Paint()..color = PhantomTheme.red.withAlpha(30));
    canvas.drawRect(
      pixelRect,
      Paint()
        ..color = PhantomTheme.red.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // SEALED label
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SEALED',
        style: TextStyle(
          color: PhantomTheme.red,
          fontSize: 18,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(
      pixelRect.center.dx - tp.width / 2,
      pixelRect.center.dy - tp.height / 2,
    ));
  }

  void _drawDeadBodies(Canvas canvas) {
    for (final body in game.state.deadBodies) {
      if (body.reported) continue;
      final wx = body.x * kWorldScale;
      final wy = body.y * kWorldScale;
      final color = PhantomTheme.playerColors[body.victimColorKey] ?? Colors.red;

      // Shadow
      canvas.drawOval(
        Rect.fromCenter(center: Offset(wx, wy + 6), width: 36, height: 14),
        Paint()
          ..color = Colors.black.withAlpha(80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Body shape (fallen crew member)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(wx, wy), width: 28, height: 16),
          const Radius.circular(4),
        ),
        Paint()..color = color.withAlpha(200),
      );
      // Red pool
      canvas.drawOval(
        Rect.fromCenter(center: Offset(wx, wy + 4), width: 36, height: 12),
        Paint()..color = Colors.red.withAlpha(60),
      );
    }
  }
}
