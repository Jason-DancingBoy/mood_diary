import 'package:flutter/material.dart';

enum MoodQuadrant {
  red,
  yellow,
  blue,
  green;

  String get label {
    switch (this) {
      case MoodQuadrant.red:
        return '红色区';
      case MoodQuadrant.yellow:
        return '黄色区';
      case MoodQuadrant.blue:
        return '蓝色区';
      case MoodQuadrant.green:
        return '绿色区';
    }
  }

  String get description {
    switch (this) {
      case MoodQuadrant.red:
        return '高能量，不愉悦';
      case MoodQuadrant.yellow:
        return '高能量，愉悦';
      case MoodQuadrant.blue:
        return '低能量，不愉悦';
      case MoodQuadrant.green:
        return '低能量，愉悦';
    }
  }

  Color get color {
    switch (this) {
      case MoodQuadrant.red:
        return const Color(0xFFE74C3C);
      case MoodQuadrant.yellow:
        return const Color(0xFFF39C12);
      case MoodQuadrant.blue:
        return const Color(0xFF3498DB);
      case MoodQuadrant.green:
        return const Color(0xFF2ECC71);
    }
  }

  Color get bgColor {
    switch (this) {
      case MoodQuadrant.red:
        return const Color(0xFFE74C3C).withValues(alpha: 0.15);
      case MoodQuadrant.yellow:
        return const Color(0xFFF39C12).withValues(alpha: 0.15);
      case MoodQuadrant.blue:
        return const Color(0xFF3498DB).withValues(alpha: 0.15);
      case MoodQuadrant.green:
        return const Color(0xFF2ECC71).withValues(alpha: 0.15);
    }
  }

  static MoodQuadrant fromEnergyPleasantness(double energy, double pleasantness) {
    if (energy >= 0 && pleasantness >= 0) return MoodQuadrant.yellow;
    if (energy >= 0 && pleasantness < 0) return MoodQuadrant.red;
    if (energy < 0 && pleasantness >= 0) return MoodQuadrant.green;
    return MoodQuadrant.blue;
  }
}
