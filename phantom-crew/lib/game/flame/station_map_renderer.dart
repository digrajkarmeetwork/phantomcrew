import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/station_map.dart';
import '../../ui/theme.dart';
import 'phantom_game.dart';

/// Tile size in world pixels.
const double _tileSize = 64.0;

/// Number of tiles along each axis.
int get _tilesX => (kWorldScale / _tileSize).ceil();
int get _tilesY => (kWorldScale / _tileSize).ceil();

/// Renders the station map using tile sprites and decorative elements.
class StationMapRenderer extends PositionComponent with HasGameReference<PhantomGame> {
  // Tile sprites (loaded from existing assets)
  Sprite? _floorTile;
  Sprite? _wallTile;
  Sprite? _consoleTile;
  Sprite? _ventClosed;
  Sprite? _taskIcon;

  // Pre-computed tile grid: 0=void, 1=floor, 2=wall_edge, 3=console
  late List<List<int>> _tileGrid;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2.all(kWorldScale);
    position = Vector2.zero();

    // Load tile sprites with fallback
    _floorTile = await _loadSprite('images/map/floor_tile_metal.png');
    _wallTile = await _loadSprite('images/map/wall_tile.png');
    _consoleTile = await _loadSprite('images/map/floor_tile_console.png');
    _ventClosed = await _loadSprite('images/map/vent_grate_closed.png');
    _taskIcon = await _loadSprite('images/map/task_station_icon.png');

    // Build tile grid
    _buildTileGrid();
  }

  Future<Sprite?> _loadSprite(String path) async {
    try {
      final image = await game.images.load(path);
      return Sprite(image);
    } catch (_) {
      return null;
    }
  }

  void _buildTileGrid() {
    _tileGrid = List.generate(
      _tilesY,
      (_) => List.filled(_tilesX, 0),
    );

    for (int ty = 0; ty < _tilesY; ty++) {
      for (int tx = 0; tx < _tilesX; tx++) {
        final nx = (tx * _tileSize + _tileSize / 2) / kWorldScale;
        final ny = (ty * _tileSize + _tileSize / 2) / kWorldScale;

        if (!StationMap.isWalkable(nx, ny, padding: 0.005)) {
          // Check if it's adjacent to a walkable tile (wall edge)
          final isEdge = _isNearWalkable(nx, ny);
          _tileGrid[ty][tx] = isEdge ? 2 : 0;
        } else {
          // Check if near a task zone (console tile)
          final isConsole = _isNearTaskZone(nx, ny);
          _tileGrid[ty][tx] = isConsole ? 3 : 1;
        }
      }
    }
  }

  bool _isNearWalkable(double nx, double ny) {
    const step = 0.04;
    return StationMap.isWalkable(nx - step, ny, padding: 0.005) ||
        StationMap.isWalkable(nx + step, ny, padding: 0.005) ||
        StationMap.isWalkable(nx, ny - step, padding: 0.005) ||
        StationMap.isWalkable(nx, ny + step, padding: 0.005);
  }

  bool _isNearTaskZone(double nx, double ny) {
    for (final zone in StationMap.taskZones.values) {
      final dx = zone.dx - nx;
      final dy = zone.dy - ny;
      if (dx * dx + dy * dy < 0.002) return true;
    }
    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw space background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kWorldScale, kWorldScale),
      Paint()..color = const Color(0xFF040810),
    );

    // Draw tiles
    for (int ty = 0; ty < _tilesY; ty++) {
      for (int tx = 0; tx < _tilesX; tx++) {
        final tileType = _tileGrid[ty][tx];
        if (tileType == 0) continue;

        final pos = Vector2(tx * _tileSize, ty * _tileSize);
        final tileSize = Vector2.all(_tileSize);

        switch (tileType) {
          case 1: // Floor
            if (_floorTile != null) {
              _floorTile!.render(canvas, position: pos, size: tileSize);
            } else {
              _drawFallbackTile(canvas, pos, const Color(0xFF111827));
            }
          case 2: // Wall edge
            if (_wallTile != null) {
              _wallTile!.render(canvas, position: pos, size: tileSize);
            } else {
              _drawFallbackTile(canvas, pos, const Color(0xFF1A2540));
            }
          case 3: // Console (near task zones)
            if (_consoleTile != null) {
              _consoleTile!.render(canvas, position: pos, size: tileSize);
            } else {
              _drawFallbackTile(canvas, pos, const Color(0xFF0F1F2E));
            }
        }
      }
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

  void _drawFallbackTile(Canvas canvas, Vector2 pos, Color color) {
    canvas.drawRect(
      Rect.fromLTWH(pos.x, pos.y, _tileSize, _tileSize),
      Paint()..color = color,
    );
    // Subtle grid line
    canvas.drawRect(
      Rect.fromLTWH(pos.x, pos.y, _tileSize, _tileSize),
      Paint()
        ..color = const Color(0xFF1E2D45).withAlpha(40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawRoomLabels(Canvas canvas) {
    for (final entry in StationMap.rooms.entries) {
      final r = entry.value;
      final cx = r.center.dx * kWorldScale;
      final cy = r.top * kWorldScale + 24;

      final tp = TextPainter(
        text: TextSpan(
          text: entry.key.toUpperCase(),
          style: TextStyle(
            color: const Color(0xFF4A6A8A).withAlpha(180),
            fontSize: 14,
            fontFamily: 'Orbitron',
            letterSpacing: 2,
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
      final ventSize = Vector2(40, 28);

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
          width: 40,
          height: 28,
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
            Offset(wx - 14, wy + i * 7.0),
            Offset(wx + 14, wy + i * 7.0),
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
          position: Vector2(wx - 16, wy - 16),
          size: Vector2.all(32),
        );
      }

      // Outer glow ring
      canvas.drawCircle(
        Offset(wx, wy),
        20,
        Paint()..color = PhantomTheme.teal.withAlpha(30),
      );
      // Inner dot
      canvas.drawCircle(
        Offset(wx, wy),
        6,
        Paint()..color = PhantomTheme.teal.withAlpha(200),
      );
      // Ring
      canvas.drawCircle(
        Offset(wx, wy),
        12,
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
        Offset(wx, wy), 24,
        Paint()..color = PhantomTheme.red.withAlpha(40),
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
