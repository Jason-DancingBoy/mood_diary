import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../enums/mood_type.dart';
import '../models/mood_log.dart';
import 'mood_details_page.dart';

/// 曲线图时间范围枚举
enum ChartRange { week, month, all }

class MoodCalendarPage extends StatefulWidget {
  final List<MoodLog> logs;

  const MoodCalendarPage({super.key, required this.logs});

  @override
  State<MoodCalendarPage> createState() => _MoodCalendarPageState();
}

class _MoodCalendarPageState extends State<MoodCalendarPage> {
  late DateTime _currentMonth;
  int? _selectedDay;
  ChartRange _chartRange = ChartRange.week;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
      _selectedDay = null;
    });
  }

  int _daysInMonth(DateTime dt) {
    final nextMonth = DateTime(dt.year, dt.month + 1, 0);
    return nextMonth.day;
  }

  Map<int, Set<MoodType>> get _calendarMoodMap {
    final Map<int, Set<MoodType>> map = {};
    for (final log in widget.logs) {
      if (log.createdAt.year != _currentMonth.year ||
          log.createdAt.month != _currentMonth.month) {
        continue;
      }
      final day = log.createdAt.day;
      map.putIfAbsent(day, () => {}).add(log.mood);
    }
    return map;
  }

  Map<MoodType, int> get _monthMoodCounts {
    final Map<MoodType, int> counts = {};
    for (final log in widget.logs) {
      if (log.createdAt.year != _currentMonth.year ||
          log.createdAt.month != _currentMonth.month) {
        continue;
      }
      counts[log.mood] = (counts[log.mood] ?? 0) + 1;
    }
    return counts;
  }

  /// 获取曲线图数据
  /// 获取曲线图数据
  List<FlSpot> get _chartData {
    final now = DateTime.now();
    final spots = <FlSpot>[];

    if (_chartRange == ChartRange.all) {
      // "全部"模式：按月统计
      final Map<String, List<int>> monthlyScores = {};

      for (final log in widget.logs) {
        final monthKey = '${log.createdAt.year}-${log.createdAt.month}';
        monthlyScores.putIfAbsent(monthKey, () => []).add(log.mood.score);
      }

      if (monthlyScores.isEmpty) return spots;

      // 按月份排序
      final sortedKeys = monthlyScores.keys.toList()..sort();
      for (int i = 0; i < sortedKeys.length; i++) {
        final scores = monthlyScores[sortedKeys[i]]!;
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        spots.add(FlSpot(i.toDouble(), avg));
      }
      return spots;
    }

    // 近7天/近30天：按日统计
    int days = _chartRange == ChartRange.week ? 7 : 30;

    // 按日期分组计算每日平均分数
    final Map<int, List<int>> dailyScores = {};
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: days - 1 - i));
      final dayKey = date.year * 10000 + date.month * 100 + date.day;
      dailyScores[dayKey] = [];
    }

    for (final log in widget.logs) {
      final dayKey = log.createdAt.year * 10000 +
          log.createdAt.month * 100 +
          log.createdAt.day;
      if (dailyScores.containsKey(dayKey)) {
        dailyScores[dayKey]!.add(log.mood.score);
      }
    }

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: days - 1 - i));
      final dayKey = date.year * 10000 + date.month * 100 + date.day;
      final scores = dailyScores[dayKey]!;

      if (scores.isNotEmpty) {
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        spots.add(FlSpot(i.toDouble(), avg));
      }
    }

    return spots;
  }

  /// 获取日期标签
  List<String> get _chartLabels {
    final now = DateTime.now();
    final labels = <String>[];

    if (_chartRange == ChartRange.all) {
      // "全部"模式：按月显示标签
      final Map<String, List<int>> monthlyScores = {};

      for (final log in widget.logs) {
        final monthKey = '${log.createdAt.year}-${log.createdAt.month}';
        monthlyScores.putIfAbsent(monthKey, () => []).add(log.mood.score);
      }

      if (monthlyScores.isEmpty) return labels;

      final sortedKeys = monthlyScores.keys.toList()..sort();
      for (final key in sortedKeys) {
        final parts = key.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final date = DateTime(year, month);
        if (year == now.year) {
          labels.add(DateFormat('M月').format(date));
        } else {
          labels.add(DateFormat('yyyy/M').format(date));
        }
      }
      return labels;
    }

    // 近7天/近30天：按日显示
    int days = _chartRange == ChartRange.week ? 7 : 30;

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: days - 1 - i));
      String label;

      if (_chartRange == ChartRange.week) {
        // 一周：显示星期
        label = DateFormat('E').format(date);
      } else {
        // 一个月：显示具体日期（每5天一个标签）
        if (i % 5 == 0 || i == days - 1) {
          label = DateFormat('M/d').format(date);
        } else {
          label = '';
        }
      }
      labels.add(label);
    }
    return labels;
  }

  List<MoodLog> get _selectedDayLogs {
    if (_selectedDay == null) return [];
    return widget.logs.where((log) {
      final created = log.createdAt;
      return created.year == _currentMonth.year &&
          created.month == _currentMonth.month &&
          created.day == _selectedDay;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _openDetailForLog(MoodLog log) async {
    final box = Hive.box<Map<dynamic, dynamic>>('mood_logs_box');
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoodDetailPage(log: log, box: box),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final daysInMonth = _daysInMonth(_currentMonth);
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final moodMap = _calendarMoodMap;
    final moodCounts = _monthMoodCounts;

    List<Widget> buildDayCells() {
      final dayCells = <Widget>[];
      for (var i = 0; i < firstWeekday; i++) {
        dayCells.add(const SizedBox.shrink());
      }
      for (var day = 1; day <= daysInMonth; day++) {
        final isToday =
            today.year == _currentMonth.year &&
            today.month == _currentMonth.month &&
            today.day == day;
        final moodTypes = moodMap[day] ?? {};
        final selected = _selectedDay == day;
        dayCells.add(
          GestureDetector(
            onTap: () => setState(() {
              _selectedDay = day;
            }),
            onDoubleTap: () {
              final dayLogs = widget.logs.where((log) {
                final created = log.createdAt;
                return created.year == _currentMonth.year &&
                    created.month == _currentMonth.month &&
                    created.day == day;
              }).toList();
              if (dayLogs.isNotEmpty) {
                _openDetailForLog(dayLogs.first);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : (isToday
                            ? theme.colorScheme.primary
                            : Colors.transparent),
                  width: selected ? 2 : (isToday ? 1.5 : 0),
                ),
                color: selected
                    ? theme.colorScheme.primary.withAlpha(30)
                    : null,
              ),
              // 1. 减小 padding，给内容更多空间
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment:
                    MainAxisAlignment.center, // 2. 居中对齐，避免顶部对齐导致底部溢出
                children: [
                  Text(
                    day.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14, // 3. 稍微减小字体大小，防止日期文字过高
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4), // 4. 减小间距，从 8 改为 4
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 2, // 5. 减小圆点间距
                      runSpacing: 2, // 5. 减小圆点行间距
                      children: moodTypes
                          .map(
                            (mood) => Container(
                              width:
                                  6, // 6. 稍微增大一点圆点以便可见，或者保持 4-5，但如果空间紧张，保持小尺寸
                              height: 6,
                              decoration: BoxDecoration(
                                color: mood.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      while (dayCells.length < rows * 7) {
        dayCells.add(const SizedBox.shrink());
      }
      return dayCells;
    }

    Widget buildSelectedDaySection() {
      if (_selectedDay == null) return const SizedBox.shrink();
      final selectedDay = _selectedDay!;
      if (_selectedDayLogs.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$selectedDay日记录',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('该天没有心情记录', style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 16),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$selectedDay日记录',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._selectedDayLogs.map((log) {
            final timeLabel =
                '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';
            return GestureDetector(
              onDoubleTap: () => _openDetailForLog(log),
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: log.mood.color,
                            child: Icon(
                              log.mood.icon,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              log.displayLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(timeLabel, style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        log.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '双击查看详情',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_currentMonth.year}年${_currentMonth.month.toString().padLeft(2, '0')}月 心情日历',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeMonth(-1),
                      tooltip: '上个月',
                    ),
                    Text(
                      '${_currentMonth.year}年${_currentMonth.month}月',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeMonth(1),
                      tooltip: '下个月',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '本月心情统计',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (moodCounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '当前月份还没有心情记录',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  Wrap(
                    runSpacing: 10,
                    spacing: 10,
                    children: moodCounts.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: entry.key.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${entry.key.label} x ${entry.value}'),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Expanded(child: Center(child: Text('日'))),
                          Expanded(child: Center(child: Text('一'))),
                          Expanded(child: Center(child: Text('二'))),
                          Expanded(child: Center(child: Text('三'))),
                          Expanded(child: Center(child: Text('四'))),
                          Expanded(child: Center(child: Text('五'))),
                          Expanded(child: Center(child: Text('六'))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                        physics: const NeverScrollableScrollPhysics(),
                        children: buildDayCells(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                buildSelectedDaySection(),
                // 心情趋势曲线图
                _buildMoodTrendChart(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建心情趋势曲线图
  Widget _buildMoodTrendChart(ThemeData theme) {
    final spots = _chartData;
    final hasData = spots.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 范围选择器
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SegmentedButton<ChartRange>(
              segments: const [
                ButtonSegment(value: ChartRange.week, label: Text('近7天')),
                ButtonSegment(value: ChartRange.month, label: Text('近30天')),
                ButtonSegment(value: ChartRange.all, label: Text('全部')),
              ],
              selected: {_chartRange},
              onSelectionChanged: (selection) {
                setState(() {
                  _chartRange = selection.first;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 图表
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: hasData
              ? LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 10,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 2,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            final labels = _chartLabels;
                            if (index < 0 || index >= labels.length) {
                              return const SizedBox.shrink();
                            }
                            final label = labels[index];
                            if (label.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 2,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.outline,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: theme.colorScheme.primary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: spots.length <= 14,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: theme.colorScheme.primary,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.x.toInt();
                            // 计算对应日期/月份
                            if (_chartRange == ChartRange.all) {
                              // "全部"模式：显示月份
                              final labels = _chartLabels;
                              String label = labels.isNotEmpty && index < labels.length
                                  ? labels[index]
                                  : '';
                              return LineTooltipItem(
                                '$label\n${spot.y.toStringAsFixed(1)}分',
                                TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }
                            final now = DateTime.now();
                            int days = _chartRange == ChartRange.week ? 7 : 30;
                            final date = now.subtract(Duration(days: days - 1 - index));
                            final dateStr = DateFormat('M月d日').format(date);
                            return LineTooltipItem(
                              '$dateStr\n${spot.y.toStringAsFixed(1)}分',
                              TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 48,
                        color: theme.colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '暂无数据',
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 8),
        // 图例说明
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(theme, '😊 幸福', Colors.deepOrangeAccent, 10),
            _buildLegendItem(theme, '🙂 开心', Colors.pink, 8),
            _buildLegendItem(theme, '😌 平静', Colors.teal, 7),
            _buildLegendItem(theme, '😢 难过', Colors.blue, 3),
            _buildLegendItem(theme, '😠 厌恶', Colors.lime, 1),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLegendItem(ThemeData theme, String label, Color color, int score) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
