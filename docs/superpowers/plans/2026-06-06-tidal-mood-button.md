# Tidal Mood Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bottom FAB "记录心情" button with a centered animated tidal button that reflects mood energy/pleasantness via water level and background color.

**Architecture:** New `TidalMoodButton` StatefulWidget using CustomPaint for wave+heart rendering, two AnimationControllers (breathing + wave flow). Modify `MoodListPage` to compute energy/pleasantness from the most recent log and pass them to the button.

**Tech Stack:** Flutter SDK ^3.12, native AnimationController + CustomPaint (no extra deps needed)

---

## File Structure

- **Create**: `lib/widgets/tidal_mood_button.dart` — TidalMoodButton widget + TidalMoodPainter
- **Modify**: `lib/pages/mood_list_page.dart` — replace FAB, compute energy/pleasantness from recent log
---



### Task 1: Create TidalMoodPainter (CustomPainter for wave + heart)

**Files:**
- Create: `lib/widgets/tidal_mood_button.dart`

- [ ] **Step 1: Write the file skeleton with TidalMoodPainter**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// CustomPainter that renders the tidal mood button interior:
/// rounded rect background → heart clip → dual wave layers.
class TidalMoodPainter extends CustomPainter {
  final double waterLevel;    // 0.0–1.0, driven by energy
  final double wavePhase1;    // first wave layer horizontal offset (0–2π)
  final double wavePhase2;    // second wave layer horizontal offset
  final Color bgColor1;       // background gradient start
  final Color bgColor2;       // background gradient end
  final Color waterColor1;    // wave layer 1 color
  final Color waterColor2;    // wave layer 2 color

  TidalMoodPainter({
    required this.waterLevel,
    required this.wavePhase1,
    required this.wavePhase2,
    required this.bgColor1,
    required this.bgColor2,
    required this.waterColor1,
    required this.waterColor2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.233), // 28/120
    );

    // 1. Draw background rounded rect with gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [bgColor1, bgColor2],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rect, bgPaint);

    // 2. Build heart path centered in the rect
    final heartPath = _buildHeartPath(size);

    // 3. Draw the full heart filled with red (above-water portion)
    final heartPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;
    canvas.drawPath(heartPath, heartPaint);

    // 4. Clip to heart path, then draw wave layers on top (below-water portion)
    //    This covers the bottom of the red heart with gradient water colors.
    canvas.save();
    canvas.clipPath(heartPath);
    _drawWave(canvas, size, wavePhase1, waterColor1, 0.0);
    _drawWave(canvas, size, wavePhase2, waterColor2, 12.0);
    canvas.restore();
  }

  Path _buildHeartPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 3; // slight downward adjust for visual balance
    final s = size.width / 130 * 0.92;
    final path = Path();
    // P1 Q-plump heart: centered around origin, then translated
    path.moveTo(cx, cy + (-10) * s);
    path.cubicTo(cx + (-34) * s, cy + (-40) * s, cx + (-56) * s, cy + (-4) * s, cx + (-28) * s, cy + 18 * s);
    path.cubicTo(cx + (-10) * s, cy + 34 * s, cx, cy + 46 * s, cx, cy + 46 * s);
    path.cubicTo(cx, cy + 46 * s, cx + 10 * s, cy + 34 * s, cx + 28 * s, cy + 18 * s);
    path.cubicTo(cx + 56 * s, cy + (-4) * s, cx + 34 * s, cy + (-40) * s, cx, cy + (-10) * s);
    path.close();
    return path;
  }

  void _drawWave(Canvas canvas, Size size, double phase, Color color, double yOffset) {
    final baseY = size.height * (1.0 - waterLevel) + yOffset;
    final amplitude = size.height * 0.08;
    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 2) {
      final normalizedX = x / size.width;
      final y = baseY + amplitude * math.sin(normalizedX * 2 * math.pi * 1.3 + phase);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();

    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TidalMoodPainter oldDelegate) {
    return oldDelegate.waterLevel != waterLevel ||
        oldDelegate.wavePhase1 != wavePhase1 ||
        oldDelegate.wavePhase2 != wavePhase2 ||
        oldDelegate.bgColor1 != bgColor1 ||
        oldDelegate.bgColor2 != bgColor2 ||
        oldDelegate.waterColor1 != waterColor1 ||
        oldDelegate.waterColor2 != waterColor2;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/tidal_mood_button.dart
git commit -m "feat: add TidalMoodPainter for wave+heart rendering"
```

---

### Task 2: Create TidalMoodButton widget

**Files:**
- Modify: `lib/widgets/tidal_mood_button.dart` (append to file)

- [ ] **Step 1: Add necessary imports and color helpers**

Append these imports at the top of the file (above TidalMoodPainter):

```dart
// Already imported: dart:math, flutter/material.dart
// No additional imports needed
```

- [ ] **Step 2: Add helper function for pleasantness→background colors**

Insert between imports and TidalMoodPainter:

```dart
/// Map pleasantness (-1..1) to background gradient colors.
/// High pleasantness → warm pink/peach tones
/// Low pleasantness → cool blue/indigo tones
({Color c1, Color c2}) _pleasantnessColors(double? pleasantness) {
  final p = (pleasantness ?? 0).clamp(-1.0, 1.0);
  if (p >= 0) {
    // Interpolate from neutral purple to warm pink
    final t = p;
    return (
      c1: Color.lerp(const Color(0xFFE8D5F5), const Color(0xFFFFE0E8), t)!,
      c2: Color.lerp(const Color(0xFFE0E0F5), const Color(0xFFD5E5FF), t)!,
    );
  } else {
    // Interpolate from neutral purple to cool deep blue
    final t = -p;
    return (
      c1: Color.lerp(const Color(0xFFE8D5F5), const Color(0xFFC8D8E8), t)!,
      c2: Color.lerp(const Color(0xFFE0E0F5), const Color(0xFFD0C0E8), t)!,
    );
  }
}
```

- [ ] **Step 3: Add water color helper function**

```dart
/// Map pleasantness to wave gradient colors.
({Color c1, Color c2}) _waterColors(double? pleasantness) {
  final p = (pleasantness ?? 0).clamp(-1.0, 1.0);
  if (p >= 0) {
    final t = p;
    return (
      c1: Color.lerp(const Color(0xFF7C4DFF), const Color(0xFFFF6B8A), t)!,
      c2: Color.lerp(const Color(0xFF448AFF), const Color(0xFF7C4DFF), t)!,
    );
  } else {
    final t = -p;
    return (
      c1: Color.lerp(const Color(0xFF7C4DFF), const Color(0xFF1A237E), t)!,
      c2: Color.lerp(const Color(0xFF448AFF), const Color(0xFF4527A0), t)!,
    );
  }
}
```

- [ ] **Step 4: Write the TidalMoodButton StatefulWidget**

Append at end of file:

```dart
class TidalMoodButton extends StatefulWidget {
  final double? energy;
  final double? pleasantness;
  final bool compact;
  final VoidCallback onPressed;

  const TidalMoodButton({
    super.key,
    this.energy,
    this.pleasantness,
    this.compact = false,
    required this.onPressed,
  });

  @override
  State<TidalMoodButton> createState() => _TidalMoodButtonState();
}

class _TidalMoodButtonState extends State<TidalMoodButton>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _waveController;
  late Animation<double> _breatheAnim;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _breatheAnim = CurvedAnimation(
      parent: _breatheController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  double get _waterLevel {
    final e = widget.energy;
    if (e == null) return 0.5;
    return ((e.clamp(-1.0, 1.0) + 1.0) / 2.0 * 0.8 + 0.1).clamp(0.1, 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 100.0 : 120.0;
    final borderRadius = widget.compact ? 24.0 : 28.0;
    final bgColors = _pleasantnessColors(widget.pleasantness);
    final wColors = _waterColors(widget.pleasantness);

    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breatheAnim, _waveController]),
        builder: (context, _) {
          final scale = 1.0 + _breatheAnim.value * 0.04;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: bgColors.c1.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: bgColors.c1.withValues(alpha: 0.05),
                    blurRadius: 0,
                    spreadRadius: 8 * (1 + _breatheAnim.value * 0.5),
                  ),
                  BoxShadow(
                    color: bgColors.c1.withValues(alpha: 0.03),
                    blurRadius: 0,
                    spreadRadius: 18 * (1 + _breatheAnim.value * 0.33),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: CustomPaint(
                  painter: TidalMoodPainter(
                    waterLevel: _waterLevel,
                    wavePhase1: _waveController.value * 2 * math.pi,
                    wavePhase2: _waveController.value * 2 * math.pi + math.pi / 3,
                    bgColor1: bgColors.c1,
                    bgColor2: bgColors.c2,
                    waterColor1: wColors.c1,
                    waterColor2: wColors.c2,
                  ),
                  size: Size(size, size),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run build to verify no compilation errors**

```bash
flutter analyze lib/widgets/tidal_mood_button.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/tidal_mood_button.dart
git commit -m "feat: add TidalMoodButton widget with breathing + wave animations"
```

---

### Task 3: Integrate TidalMoodButton into MoodListPage

**Files:**
- Modify: `lib/pages/mood_list_page.dart`

- [ ] **Step 1: Add import at top of mood_list_page.dart**

```dart
// Add near other widget imports:
import '../widgets/tidal_mood_button.dart';
```

- [ ] **Step 2: Add helper to get latest energy/pleasantness from box**

Add this method to `_MoodListPageState`:

```dart
/// Get energy/pleasantness from the most recent mood log.
/// Returns (null, null) if no logs exist or the latest log lacks these fields.
(double?, double?) _latestMoodEnergyPleasantness() {
  final keys = _box.keys.toList();
  if (keys.isEmpty) return (null, null);
  keys.sort((a, b) {
    final mapA = _box.get(a)!;
    final mapB = _box.get(b)!;
    final timeA = mapA['createdAt'] as DateTime;
    final timeB = mapB['createdAt'] as DateTime;
    return timeB.compareTo(timeA);
  });
  final latest = _box.get(keys.first);
  if (latest == null) return (null, null);
  return (
    (latest['energy'] as num?)?.toDouble(),
    (latest['pleasantness'] as num?)?.toDouble(),
  );
}
```

- [ ] **Step 3: Replace the bottom FAB with the tidal button in the empty state area**

Find the empty state widget at lines 441-464 (inside `SliverFillRemaining`). Replace the icon+text placeholder with the tidal button:

Replace this block (lines 443-464):
```dart
child: Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.sentiment_neutral,
        size: 72,
        color: theme.colorScheme.primary.withValues(
          alpha: 0.4,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        '暂无心情记录，快去写一条吧~',
        style: TextStyle(
          color: _getCorrectColor(theme, tp.$1, tp.$2),
        ),
      ),
    ],
  ),
),
```

With:
```dart
child: Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(height: 32),
      TidalMoodButton(
        energy: null,
        pleasantness: null,
        onPressed: () => _showAddLogDialog(context),
      ),
      const SizedBox(height: 16),
      Text(
        '点击记录今日心情',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _getCorrectColor(theme, tp.$1, tp.$2).withValues(alpha: 0.6),
        ),
      ),
    ],
  ),
),
```

- [ ] **Step 4: Replace the bottom FAB (lines 501-509) with tidal button for non-empty state**

Replace:
```dart
else if (!_isSelectionMode)
  Padding(
    padding: const EdgeInsets.all(16),
    child: FloatingActionButton.extended(
      onPressed: () => _showAddLogDialog(context),
      icon: const Icon(Icons.edit_note),
      label: const Text('记录心情'),
    ),
  ),
```

With:
```dart
else if (!_isSelectionMode)
  Builder(builder: (context) {
    final (energy, pleasantness) = _latestMoodEnergyPleasantness();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: TidalMoodButton(
          energy: energy,
          pleasantness: pleasantness,
          compact: true,
          onPressed: () => _showAddLogDialog(context),
        ),
      ),
    );
  }),
```

- [ ] **Step 5: Run flutter analyze to verify no errors**

```bash
flutter analyze lib/pages/mood_list_page.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/pages/mood_list_page.dart
git commit -m "feat: replace FAB with TidalMoodButton in mood list page"
```

---

### Task 4: Verification

**Files:**
- None (manual verification)

- [ ] **Step 1: Run full analysis**

```bash
flutter analyze
```

Expected: No issues found.

- [ ] **Step 2: Run existing tests**

```bash
flutter test
```

Expected: All existing tests pass.

- [ ] **Step 3: Manual verification checklist**

Launch the app (`flutter run`) and verify:
- [ ] Empty state: tidal button centered, breathing animation visible, default 50% water
- [ ] With records: compact tidal button below list, water level reflects latest mood's energy
- [ ] Background color changes with pleasantness
- [ ] Tap button: opens LogEditorDialog, record, verify button updates after new record
- [ ] Batch selection mode: tidal button is not visible (replaced by batch delete bar)
- [ ] Wave animation is smooth and continuous (not static)

- [ ] **Step 4: Commit any final tweaks if needed**

```bash
git add -A && git commit -m "chore: final polish on tidal button integration"
```
