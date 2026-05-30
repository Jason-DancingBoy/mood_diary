import 'package:flutter_test/flutter_test.dart';
import 'package:mood_diary/services/version_service.dart';

void main() {
  group('VersionService.isNewer', () {
    // ---- 基本比较 ----
    test('latest 比 current 大时返回 true', () {
      expect(VersionService.isNewer('1.0.0', '1.0.1'), isTrue);
      expect(VersionService.isNewer('1.0.0', '1.1.0'), isTrue);
      expect(VersionService.isNewer('1.0.0', '2.0.0'), isTrue);
      expect(VersionService.isNewer('1.0.0', '1.0.10'), isTrue);
      expect(VersionService.isNewer('0.9.0', '1.0.0'), isTrue);
    });

    test('版本相同时返回 false', () {
      expect(VersionService.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(VersionService.isNewer('0.0.1', '0.0.1'), isFalse);
      expect(VersionService.isNewer('10.20.30', '10.20.30'), isFalse);
    });

    test('current 比 latest 大时返回 false (降级保护)', () {
      expect(VersionService.isNewer('2.0.0', '1.0.0'), isFalse);
      expect(VersionService.isNewer('1.0.1', '1.0.0'), isFalse);
      expect(VersionService.isNewer('1.10.0', '1.2.0'), isFalse);
    });

    // ---- 不等长版本号 ----
    test('处理不等长版本号：latest 更长', () {
      expect(VersionService.isNewer('1.0', '1.0.1'), isTrue);
      expect(VersionService.isNewer('1', '1.0.1'), isTrue);
    });

    test('处理不等长版本号：current 更长', () {
      expect(VersionService.isNewer('1.0.0', '1.0'), isFalse);
      expect(VersionService.isNewer('1.0.1', '1'), isFalse);
    });

    test('不等长版本号相等', () {
      expect(VersionService.isNewer('1.0', '1.0.0'), isFalse);
      expect(VersionService.isNewer('1.0.0', '1.0'), isFalse);
      expect(VersionService.isNewer('1', '1.0.0'), isFalse);
    });

    // ---- 构建元数据 ----
    test('构建元数据(+build)不影响版本比较', () {
      expect(VersionService.isNewer('1.0.6+10', '1.0.7+3'), isTrue);
      expect(VersionService.isNewer('1.0.6+10', '1.0.6+5'), isFalse);
      expect(VersionService.isNewer('1.0.6+5', '1.0.6+10'), isFalse);
    });

    // ---- 预发布标识 ----
    test('预发布标识(-pre)被剥离后与核心版本号比较', () {
      // clean() 会剥离 -pre 部分，所以 1.0.0-beta 和 1.0.0 被视为相同版本
      expect(VersionService.isNewer('1.0.0-beta', '1.0.0'), isFalse);
      expect(VersionService.isNewer('1.0.0', '1.0.0-beta'), isFalse);
      // 主版本号更大时仍然正确
      expect(VersionService.isNewer('1.0.0-beta', '1.0.1'), isTrue);
      expect(VersionService.isNewer('1.0.0-beta', '1.1.0'), isTrue);
    });

    // ---- 畸形输入安全性 ----
    test('含非数字的版本号不抛异常', () {
      expect(
        () => VersionService.isNewer('abc', '1.0.0'),
        returnsNormally,
      );
      expect(
        () => VersionService.isNewer('1.0.0', 'xyz'),
        returnsNormally,
      );
    });

    test('空字符串不抛异常', () {
      expect(
        () => VersionService.isNewer('', '1.0.0'),
        returnsNormally,
      );
      expect(
        () => VersionService.isNewer('1.0.0', ''),
        returnsNormally,
      );
    });

    test('空字符串不等于正常版本', () {
      // 空字符串 clean 后仍然是空，parseInt 会失败进入 catch
      // catch 返回 clean(current) != clean(latest)
      expect(VersionService.isNewer('', '1.0.0'), isTrue);
      expect(VersionService.isNewer('1.0.0', ''), isTrue);
    });

    // ---- 真实版本号 ----
    test('真实版本号比较 (当前项目版本 1.0.6)', () {
      // 当前版本 1.0.6+10
      expect(VersionService.isNewer('1.0.6', '1.0.7'), isTrue);
      expect(VersionService.isNewer('1.0.6', '1.1.0'), isTrue);
      expect(VersionService.isNewer('1.0.6', '2.0.0'), isTrue);
      expect(VersionService.isNewer('1.0.6', '1.0.6'), isFalse);
      expect(VersionService.isNewer('1.0.6', '1.0.5'), isFalse);
    });

    test('两位数次版本号比较', () {
      expect(VersionService.isNewer('1.0.9', '1.0.10'), isTrue);
      expect(VersionService.isNewer('1.0.10', '1.0.9'), isFalse);
      expect(VersionService.isNewer('1.9.0', '1.10.0'), isTrue);
      expect(VersionService.isNewer('1.10.0', '1.9.0'), isFalse);
    });
  });
}
