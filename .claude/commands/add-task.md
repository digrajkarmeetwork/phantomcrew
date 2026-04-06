# Add Task — Scaffold a New Phantom Crew Mini-Game Task

Scaffold all the boilerplate needed to add a new in-game task mini-game to Phantom Crew.

## Usage

Provide the task name and zone. Example:
```
/add-task "Plasma Vent Seal" in "Engineering Bay"
```

If no arguments are given, ask the user for:
1. Task name (e.g. "Plasma Vent Seal")
2. Which station zone (Command Bridge / Engineering Bay / Research Lab / Life Support / Comms Array)
3. Task type: timer-based | tap-sequence | slider-puzzle | swipe-gesture | wire-match

## Workflow

Make a todo list and work through each step.

### 1. Derive Identifiers

From the task name, derive:
- `task_id`: snake_case (e.g. `plasma_vent_seal`)
- `TaskClass`: PascalCase (e.g. `PlasmaVentSeal`)
- `dart_file`: `lib/game/tasks/plasma_vent_seal.dart`
- `test_file`: `test/tasks/plasma_vent_seal_test.dart`
- `asset_bg`: `assets/images/tasks/plasma_vent_seal_bg.png`

### 2. Create the Task Dart File

Create `lib/game/tasks/{task_id}.dart`:

```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/task_result.dart';

/// [TASK_NAME] — Zone: [ZONE]
/// 
/// Task type: [TASK_TYPE]
/// Description: [Brief description of the mini-game mechanic]
class [TaskClass]Task extends Component {
  static const String taskId = '[task_id]';
  static const String displayName = '[TASK_NAME]';
  static const String zone = '[ZONE]';

  bool _isComplete = false;
  bool get isComplete => _isComplete;

  // TODO: Add task-specific state fields here

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // TODO: Load task assets
  }

  /// Called when the player interacts with this task station.
  /// Returns a widget overlay for the task UI.
  Widget buildTaskUI(BuildContext context, VoidCallback onComplete) {
    return _[TaskClass]TaskWidget(
      onComplete: () {
        _isComplete = true;
        onComplete();
      },
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    // TODO: Update task state (timers, animations, etc.)
  }
}

class _[TaskClass]TaskWidget extends StatefulWidget {
  final VoidCallback onComplete;
  const _[TaskClass]TaskWidget({required this.onComplete});

  @override
  State<_[TaskClass]TaskWidget> createState() => _[TaskClass]TaskWidgetState();
}

class _[TaskClass]TaskWidgetState extends State<_[TaskClass]TaskWidget> {
  // TODO: Add widget state

  @override
  Widget build(BuildContext context) {
    return Container(
      // TODO: Implement task UI
      // Background: AssetImage('[asset_bg]')
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '[TASK_NAME]',
              style: const TextStyle(color: Colors.tealAccent, fontSize: 24),
            ),
            const SizedBox(height: 16),
            // TODO: Task-specific controls
            ElevatedButton(
              onPressed: widget.onComplete,  // Replace with real completion logic
              child: const Text('Complete Task'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Replace all `[PLACEHOLDER]` values with real content.

### 3. Register the Task

In `lib/game/models/task_registry.dart` (create if it doesn't exist), add an entry:

```dart
import '../tasks/[task_id].dart';

// In the taskRegistry map:
'[task_id]': () => [TaskClass]Task(),
```

### 4. Add Task Zone Marker to Map

In `lib/game/components/station_map.dart`, add a task zone trigger for the new task:

```dart
TaskZone(
  taskId: '[task_id]',
  zone: '[ZONE]',
  position: Vector2(X, Y),   // TODO: Set correct position on the map
  size: Vector2(80, 80),
),
```

Ask the user for the approximate map coordinates, or leave a TODO comment.

### 5. Add Asset Placeholder

Create a placeholder file so Flutter doesn't crash on missing asset:
```bash
touch assets/images/tasks/[task_id]_bg.png
```

Add to `pubspec.yaml` under `flutter.assets`:
```yaml
    - assets/images/tasks/[task_id]_bg.png
```

Remind the user to run `/generate-assets tasks` to generate the actual asset.

### 6. Update CLAUDE.md Task Table

In CLAUDE.md Section 7, add a row to the task table:

```markdown
| **[TASK_NAME]** | [ZONE] | [Description of mechanic] |
```

### 7. Write a Basic Test

Create `test/tasks/[task_id]_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:phantom_crew/game/tasks/[task_id].dart';

void main() {
  group('[TaskClass]Task', () {
    test('starts incomplete', () {
      final task = [TaskClass]Task();
      expect(task.isComplete, isFalse);
    });

    test('has correct task ID', () {
      expect([TaskClass]Task.taskId, equals('[task_id]'));
    });

    test('has correct zone', () {
      expect([TaskClass]Task.zone, equals('[ZONE]'));
    });
  });
}
```

### 8. Run Tests

```bash
flutter test test/tasks/[task_id]_test.dart
```

Fix any test failures before finishing.

### 9. Summary

Report:
- Files created: task dart file, test file
- Files modified: task_registry.dart, station_map.dart, pubspec.yaml, CLAUDE.md
- Next steps: implement the task UI logic, run `/generate-assets tasks` for the background image
