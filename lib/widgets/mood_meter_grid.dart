import 'package:flutter/material.dart';
import '../enums/mood_quadrant.dart';
import '../data/emotion_mapping.dart';

class MoodMeterGrid extends StatefulWidget {
  final double? initialEnergy;
  final double? initialPleasantness;

  const MoodMeterGrid({super.key, this.initialEnergy, this.initialPleasantness});

  @override
  State<MoodMeterGrid> createState() => _MoodMeterGridState();
}

class _MoodMeterGridState extends State<MoodMeterGrid> {
  static const _gridSteps = 40;

  double? _energy;
  double? _pleasantness;
  EmotionEntry? _selectedEmotion;
  List<EmotionEntry> _nearbyEmotions = [];
  late List<EmotionEntry> _displayEmotions;

  @override
  void initState() {
    super.initState();
    _displayEmotions = getDisplayEmotions(limit: 25);
    if (widget.initialEnergy != null && widget.initialPleasantness != null) {
      _energy = widget.initialEnergy!.clamp(-1.0, 1.0);
      _pleasantness = widget.initialPleasantness!.clamp(-1.0, 1.0);
      _updateSelection();
    }
  }

  void _onTap(TapUpDetails details, double width, double height) {
    final px = details.localPosition.dx.clamp(0.0, width);
    final py = details.localPosition.dy.clamp(0.0, height);
    _pleasantness = (px / width) * 2 - 1;
    _energy = 1 - (py / height) * 2;
    _updateSelection();
  }

  void _onPan(DragUpdateDetails details, double width, double height) {
    final px = details.localPosition.dx.clamp(0.0, width);
    final py = details.localPosition.dy.clamp(0.0, height);
    _pleasantness = (px / width) * 2 - 1;
    _energy = 1 - (py / height) * 2;
    _updateSelection();
  }

  void _updateSelection() {
    if (_energy == null || _pleasantness == null) return;
    setState(() {
      _selectedEmotion = findNearestEmotion(_energy!, _pleasantness!);
      _nearbyEmotions = getNearbyEmotions(_energy!, _pleasantness!, count: 6);
    });
  }

  void _selectNearby(EmotionEntry entry) {
    setState(() {
      _energy = entry.energy;
      _pleasantness = entry.pleasantness;
      _selectedEmotion = entry;
      _nearbyEmotions = getNearbyEmotions(_energy!, _pleasantness!, count: 6);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('选择你的心情坐标', style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gridSize = constraints.maxWidth;
                return Column(
                  children: [
                    // Energy label (top)
                    Text('高能量 ↑', style: theme.textTheme.bodySmall),
                    SizedBox(
                      width: gridSize,
                      height: gridSize,
                      child: GestureDetector(
                        onTapUp: (d) => _onTap(d, gridSize, gridSize),
                        onPanUpdate: (d) => _onPan(d, gridSize, gridSize),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CustomPaint(
                                size: Size(gridSize, gridSize),
                                painter: _GridBackgroundPainter(steps: _gridSteps),
                              ),
                            ),
                            // Quadrant dividing lines
                            Center(
                              child: IgnorePointer(
                                child: Container(
                                  width: gridSize,
                                  height: gridSize,
                                  child: CustomPaint(
                                    painter: _QuadrantLinesPainter(),
                                  ),
                                ),
                              ),
                            ),
                            // Emotion word labels
                            ..._buildLabels(gridSize),
                            // Selected point indicator
                            if (_energy != null && _pleasantness != null)
                              Positioned(
                                left: (_pleasantness! + 1) / 2 * gridSize - 10,
                                top: (1 - _energy!) / 2 * gridSize - 10,
                                child: const IgnorePointer(
                                  child: _SelectedDot(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Energy label (bottom)
                    Text('低能量 ↓', style: theme.textTheme.bodySmall),
                  ],
                );
              },
            ),
          ),
          // Axis labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('← 不愉悦', style: Theme.of(context).textTheme.bodySmall),
                Text('愉悦 →', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Selected emotion display
          if (_selectedEmotion != null) ...[
            _buildSelectedCard(theme),
            const SizedBox(height: 8),
            // Nearby emotions
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _nearbyEmotions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = _nearbyEmotions[index];
                  final isSelected = _selectedEmotion?.chinese == entry.chinese;
                  final quad = MoodQuadrant.fromEnergyPleasantness(entry.energy, entry.pleasantness);
                  return ChoiceChip(
                    label: Text(entry.chinese, style: const TextStyle(fontSize: 13)),
                    selected: isSelected,
                    selectedColor: quad.color.withValues(alpha: 0.4),
                    backgroundColor: quad.bgColor,
                    side: BorderSide(color: quad.color.withValues(alpha: 0.3)),
                    onSelected: (_) => _selectNearby(entry),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Confirm button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _energy != null && _pleasantness != null
                    ? () {
                        Navigator.pop(context, {
                          'energy': _energy,
                          'pleasantness': _pleasantness,
                          'emotionWord': _selectedEmotion?.chinese ?? '',
                          'quadrant': MoodQuadrant.fromEnergyPleasantness(_energy!, _pleasantness!).name,
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('确认', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSelectedCard(ThemeData theme) {
    final quad = MoodQuadrant.fromEnergyPleasantness(_energy!, _pleasantness!);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: quad.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: quad.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: quad.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _selectedEmotion?.chinese ?? quad.label,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            '能量: ${_energy!.toStringAsFixed(1)}  愉悦度: ${_pleasantness!.toStringAsFixed(1)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLabels(double gridSize) {
    final widgets = <Widget>[];
    for (final entry in _displayEmotions) {
      final left = (entry.pleasantness + 1) / 2 * gridSize;
      final top = (1 - entry.energy) / 2 * gridSize;
      // Check overlap — skip if too close to an existing label
      bool tooClose = false;
      for (final other in _displayEmotions) {
        if (other.chinese == entry.chinese) break;
        final otherLeft = (other.pleasantness + 1) / 2 * gridSize;
        final otherTop = (1 - other.energy) / 2 * gridSize;
        if ((left - otherLeft).abs() < 48 && (top - otherTop).abs() < 22) {
          tooClose = true;
          break;
        }
      }
      if (tooClose) continue;

      widgets.add(
        Positioned(
          left: left - 20,
          top: top - 10,
          child: IgnorePointer(
            child: Text(
              entry.chinese,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
                shadows: const [Shadow(color: Colors.white70, blurRadius: 2)],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

class _SelectedDot extends StatelessWidget {
  const _SelectedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.black54, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  final int steps;

  _GridBackgroundPainter({required this.steps});

  static const _red = Color(0xFFE74C3C);
  static const _yellow = Color(0xFFF1C40F);
  static const _blue = Color(0xFF3498DB);
  static const _green = Color(0xFF2ECC71);

  Color _blendFour(double nx, double ny) {
    // nx: 0 (left/unpleasant) to 1 (right/pleasant)
    // ny: 0 (bottom/low energy) to 1 (top/high energy)
    final topBlend = Color.lerp(_red, _yellow, nx)!;
    final bottomBlend = Color.lerp(_blue, _green, nx)!;
    return Color.lerp(bottomBlend, topBlend, ny)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / steps;
    final cellH = size.height / steps;
    final paint = Paint();

    for (int x = 0; x < steps; x++) {
      for (int y = 0; y < steps; y++) {
        final nx = x / steps;
        final ny = 1 - y / steps; // invert y for energy
        paint.color = _blendFour(nx, ny);
        canvas.drawRect(
          Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuadrantLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;

    // Vertical line at center (pleasantness = 0)
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    // Horizontal line at center (energy = 0)
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
