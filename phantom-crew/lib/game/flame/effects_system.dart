import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'phantom_game.dart';

/// Manages visual effects: kill bursts, vent glitch, ambient dust, sabotage warnings.
class EffectsSystem extends Component with HasGameReference<PhantomGame> {
  final _rng = Random();

  // Ambient dust timer
  double _dustTimer = 0;

  @override
  void update(double dt) {
    super.update(dt);

    // Spawn ambient dust particles periodically
    _dustTimer += dt;
    if (_dustTimer > 0.3) {
      _dustTimer = 0;
      _spawnAmbientDust();
    }
  }

  // ── Kill effect ──────────────────────────────────────────────────────────

  void spawnKillEffect(Vector2 position) {
    // Red particle burst
    final particles = List.generate(24, (_) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 60 + _rng.nextDouble() * 120;
      final life = 0.4 + _rng.nextDouble() * 0.6;
      final size = 3.0 + _rng.nextDouble() * 4.0;

      return AcceleratedParticle(
        speed: Vector2(cos(angle) * speed, sin(angle) * speed),
        acceleration: Vector2(0, 40),
        child: ComputedParticle(
          lifespan: life,
          renderer: (canvas, particle) {
            final t = particle.progress;
            final alpha = ((1.0 - t) * 255).toInt().clamp(0, 255);
            final r = size * (1.0 - t * 0.5);
            canvas.drawCircle(
              Offset.zero,
              r,
              Paint()..color = Color.fromARGB(alpha, 220, 38, 38),
            );
          },
        ),
      );
    });

    // Dark expanding ring
    final ring = ComputedParticle(
      lifespan: 0.8,
      renderer: (canvas, particle) {
        final t = particle.progress;
        final radius = 20 + t * 80;
        final alpha = ((1.0 - t) * 120).toInt().clamp(0, 255);
        canvas.drawCircle(
          Offset.zero,
          radius,
          Paint()
            ..color = Color.fromARGB(alpha, 30, 0, 0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1.0 - t),
        );
      },
    );

    parent?.add(ParticleSystemComponent(
      position: position,
      particle: Particle.generate(
        count: 1,
        lifespan: 1.0,
        generator: (_) => ComposedParticle(children: [...particles, ring]),
      ),
    ));
  }

  // ── Vent glitch effect ──────────────────────────────────────────────────

  void spawnVentEffect(Vector2 position) {
    final particles = List.generate(16, (_) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 30 + _rng.nextDouble() * 60;
      final life = 0.3 + _rng.nextDouble() * 0.4;

      return AcceleratedParticle(
        speed: Vector2(cos(angle) * speed, sin(angle) * speed),
        acceleration: Vector2(0, -20), // Float upward
        child: ComputedParticle(
          lifespan: life,
          renderer: (canvas, particle) {
            final t = particle.progress;
            final alpha = ((1.0 - t) * 200).toInt().clamp(0, 255);
            // Glitch: horizontal line segments
            final w = 6 + _rng.nextDouble() * 12;
            canvas.drawLine(
              Offset(-w / 2, 0),
              Offset(w / 2, 0),
              Paint()
                ..color = Color.fromARGB(alpha, 139, 92, 246) // Purple
                ..strokeWidth = 2,
            );
          },
        ),
      );
    });

    parent?.add(ParticleSystemComponent(
      position: position,
      particle: Particle.generate(
        count: 1,
        lifespan: 0.7,
        generator: (_) => ComposedParticle(children: particles),
      ),
    ));
  }

  // ── Sabotage warning particles ──────────────────────────────────────────

  void spawnSabotageWarning(Vector2 position) {
    final particles = List.generate(8, (_) {
      final life = 0.8 + _rng.nextDouble() * 0.4;
      return AcceleratedParticle(
        speed: Vector2(
          (_rng.nextDouble() - 0.5) * 20,
          -30 - _rng.nextDouble() * 20,
        ),
        child: ComputedParticle(
          lifespan: life,
          renderer: (canvas, particle) {
            final t = particle.progress;
            final alpha = ((1.0 - t) * 180).toInt().clamp(0, 255);
            canvas.drawCircle(
              Offset.zero,
              2 + 2 * (1.0 - t),
              Paint()..color = Color.fromARGB(alpha, 239, 68, 68),
            );
          },
        ),
      );
    });

    parent?.add(ParticleSystemComponent(
      position: position,
      particle: Particle.generate(
        count: 1,
        lifespan: 1.2,
        generator: (_) => ComposedParticle(children: particles),
      ),
    ));
  }

  // ── Ambient dust ────────────────────────────────────────────────────────

  void _spawnAmbientDust() {
    // Spawn near the camera viewfinder
    final cam = game.camera.viewfinder.position;
    final viewSize = game.size;

    // Random position within visible area
    final x = cam.x + (_rng.nextDouble() - 0.5) * viewSize.x;
    final y = cam.y + (_rng.nextDouble() - 0.5) * viewSize.y;

    final life = 2.0 + _rng.nextDouble() * 3.0;
    final driftX = (_rng.nextDouble() - 0.5) * 8;
    final driftY = -2 - _rng.nextDouble() * 4;
    final size = 1.0 + _rng.nextDouble() * 1.5;

    parent?.add(ParticleSystemComponent(
      position: Vector2(x, y),
      particle: AcceleratedParticle(
        speed: Vector2(driftX, driftY),
        child: ComputedParticle(
          lifespan: life,
          renderer: (canvas, particle) {
            final t = particle.progress;
            // Fade in then out
            final alpha = t < 0.2
                ? (t / 0.2 * 40).toInt()
                : ((1.0 - t) / 0.8 * 40).toInt();
            canvas.drawCircle(
              Offset.zero,
              size,
              Paint()..color = Color.fromARGB(alpha.clamp(0, 255), 180, 200, 220),
            );
          },
        ),
      ),
    ));
  }
}
