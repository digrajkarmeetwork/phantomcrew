# Design Review — Validate Implementation Against Phantom Crew Design

Review the current state of the Phantom Crew implementation against the design spec in CLAUDE.md.
Produce a gap analysis and prioritised action list.

## Workflow

Make a todo list and work through each step.

### 1. Read the Design Spec

Read CLAUDE.md in full. Extract:
- Required screens (Section 10)
- Required characters and cosmetics (Section 5)
- Required tasks (Section 7)
- Required sabotages (Section 8)
- Asset checklist (Section 11)
- Technical architecture requirements (Section 9)

### 2. Audit the Flutter Project

Check `lib/` for existing Dart files. Map what exists:
- Which screens have been implemented?
- Which tasks have been implemented?
- Which game components (player, phantom, vent, task zone) exist?
- Is the relay client implemented?
- Is the game protocol implemented?

### 3. Audit Assets

Check `assets/images/` for existing generated assets.
Compare against the Required Assets Checklist in CLAUDE.md Section 11.

### 4. Audit Tests

Check `test/` for existing tests.
Count: total test files, tests that pass, tests that fail.

### 5. Run Static Analysis

```bash
flutter analyze 2>&1 | tail -20
```

### 6. Produce Gap Analysis Report

Format the report as:

```
## Phantom Crew Design Review — [DATE]

### Screens
✅ Implemented: [list]
❌ Missing: [list]

### Tasks
✅ Implemented: [list]
❌ Missing: [list]

### Sabotages
✅ Implemented: [list]
❌ Missing: [list]

### Characters & Cosmetics
✅ Assets present: [count]
❌ Assets missing: [count — list]

### Technical
✅ [component]: done
❌ [component]: not started / partially done

### Test Coverage
- Test files: N
- Passing: N
- Failing: N

### Static Analysis
- Errors: N
- Warnings: N

---

## Prioritised Action List

P1 (Blocker — required for any playable build):
1. ...

P2 (Required for feature-complete v1.0):
1. ...

P3 (Nice to have / polish):
1. ...
```

### 7. Offer Next Steps

Ask the user which priority they want to tackle next.
Suggest the most appropriate skill:
- Missing assets → `/generate-assets`
- Missing tasks → `/add-task`
- Build issues → `/build-mobile`
