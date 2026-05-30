import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 知识库条目得分
class _ScoredEntry {
  final Map<String, dynamic> entry;
  final double score;
  final Set<String> matchedTags;

  _ScoredEntry(this.entry, this.score, this.matchedTags);
}

/// 本地知识库服务 — 基于关键词+主题标签的检索
class KnowledgeBaseService {
  static final KnowledgeBaseService _instance = KnowledgeBaseService._();
  factory KnowledgeBaseService() => _instance;
  KnowledgeBaseService._();

  Map<String, dynamic>? _kb;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final jsonStr =
        await rootBundle.loadString('assets/mayday_knowledge.json');
    _kb = jsonDecode(jsonStr) as Map<String, dynamic>;
    _loaded = true;
  }

  bool get isLoaded => _loaded;

  /// 搜索知识库，返回格式化的上下文文本
  /// [query] 用户的消息
  /// [maxResults] 最大返回条数
  String? search(String query, {int maxResults = 3}) {
    if (!_loaded || _kb == null) {
      debugPrint('[知识库] 未加载，跳过检索');
      return null;
    }

    final results = _searchAll(query, maxResults);
    if (results.isEmpty) {
      debugPrint('[知识库] 未命中: "$query"');
      return null;
    }

    debugPrint('[知识库] 命中 ${results.length} 条: ${results.map((e) => e.entry["title"] ?? e.entry["name"]).join(", ")}');
    return _formatContext(results);
  }

  List<_ScoredEntry> _searchAll(String query, int maxResults) {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return [];

    final scored = <_ScoredEntry>[];

    // 搜索歌曲
    final songs = _kb!['songs'] as List<dynamic>? ?? [];
    for (final song in songs) {
      final s = song as Map<String, dynamic>;
      final result = _scoreSong(s, tokens);
      if (result != null) scored.add(result);
    }

    // 搜索专辑
    final albums = _kb!['albums'] as List<dynamic>? ?? [];
    for (final album in albums) {
      final a = album as Map<String, dynamic>;
      final result = _scoreAlbum(a, tokens);
      if (result != null) scored.add(result);
    }

    // 搜索成员
    final members = _kb!['members'] as List<dynamic>? ?? [];
    for (final member in members) {
      final m = member as Map<String, dynamic>;
      final result = _scoreMember(m, tokens);
      if (result != null) scored.add(result);
    }

    // 搜索事实
    final facts = _kb!['facts'] as List<dynamic>? ?? [];
    for (final fact in facts) {
      final f = fact as Map<String, dynamic>;
      final result = _scoreFact(f, tokens);
      if (result != null) scored.add(result);
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // 去重（同标题只保留最高分）
    final seen = <String>{};
    final unique = <_ScoredEntry>[];
    for (final e in scored) {
      final title = e.entry['title'] ?? e.entry['name'] ?? '';
      if (seen.contains(title)) continue;
      seen.add(title);
      unique.add(e);
    }

    // 不截断与 boundary 条目同分的其他条目（避免"5个成员只返回3个"）
    if (unique.length <= maxResults) return unique;
    final threshold = unique[maxResults - 1].score;
    return unique.where((e) => e.score >= threshold).toList();
  }

  /// 概念匹配：token 是否命中「概念词列表」中的任何一个
  bool _matchesConcept(String token, List<String> concepts) {
    for (final c in concepts) {
      if (token.contains(c) || c.contains(token)) return true;
    }
    return false;
  }

  // ---- 分词 ----
  List<String> _tokenize(String text) {
    // 按标点符号分割，保留中文词组
    // 用空格替换所有标点符号和空白字符
    final punctuation = RegExp(
      r'[，。！？、；：“”‘’（）【】《》\s,.!?;:()\]\[]+',
    );
    final cleaned = text.replaceAll(punctuation, ' ').trim();
    if (cleaned.isEmpty) return [];

    final words = cleaned.split(' ').where((w) => w.isNotEmpty).toList();
    final tokens = <String>{};

    for (final word in words) {
      tokens.add(word);
      // 提取 2-4 字 n-gram
      if (word.length >= 2) {
        for (int len = 2; len <= 4 && len <= word.length; len++) {
          for (int i = 0; i + len <= word.length; i++) {
            tokens.add(word.substring(i, i + len));
          }
        }
      }
    }

    return tokens.toList();
  }

  // ---- 评分函数 ----

  _ScoredEntry? _scoreSong(Map<String, dynamic> song, List<String> tokens) {
    double score = 0;
    final matchedTags = <String>{};

    final title = (song['title'] as String?) ?? '';
    final year = (song['year'] as int?)?.toString() ?? '';
    final keywords = List<String>.from(song['keywords'] as List? ?? []);
    final tags = List<String>.from(song['tags'] as List? ?? []);
    final lyrics = List<String>.from(song['lyrics'] as List? ?? []);
    final album = (song['album'] as String?) ?? '';
    final desc = (song['description'] as String?) ?? '';

    for (final token in tokens) {
      if (token.isEmpty) continue;

      // 标题精确匹配
      if (title == token) {
        score += 20;
        continue;
      }
      // 标题部分匹配
      if (title.contains(token)) {
        score += 10;
      }

      // 关键词匹配
      for (final kw in keywords) {
        if (kw.contains(token) || token.contains(kw)) {
          score += 5;
        }
      }

      // 标签匹配
      for (final tag in tags) {
        if (tag.contains(token) || token.contains(tag)) {
          score += 7;
          matchedTags.add(tag);
        }
      }

      // 歌词匹配
      for (final line in lyrics) {
        if (line.contains(token)) {
          score += 3;
          break; // 每 token 在歌词中只计一次
        }
      }

      // 专辑名匹配
      if (album.contains(token)) {
        score += 2;
      }

      // 描述匹配
      if (desc.contains(token)) {
        score += 2;
      }

      // 年份匹配
      if (year.isNotEmpty && year.contains(token)) {
        score += 3;
      }
    }

    if (score == 0) return null;
    return _ScoredEntry(song, score, matchedTags);
  }

  _ScoredEntry? _scoreAlbum(Map<String, dynamic> album, List<String> tokens) {
    double score = 0;
    final matchedTags = <String>{};
    final name = (album['name'] as String?) ?? '';
    final year = (album['year'] as int?)?.toString() ?? '';
    final tags = List<String>.from(album['tags'] as List? ?? []);
    final songs = List<String>.from(album['songs'] as List? ?? []);
    final desc = (album['description'] as String?) ?? '';

    for (final token in tokens) {
      if (token.isEmpty) continue;

      if (name.contains(token)) score += 8;
      if (year.isNotEmpty && year.contains(token)) score += 3;
      for (final tag in tags) {
        if (tag.contains(token) || token.contains(tag)) {
          score += 5;
          matchedTags.add(tag);
        }
      }
      for (final s in songs) {
        if (s.contains(token)) score += 2;
      }
      if (desc.contains(token)) score += 1;
    }

    if (score == 0) return null;
    return _ScoredEntry(album, score, matchedTags);
  }

  _ScoredEntry? _scoreMember(Map<String, dynamic> member, List<String> tokens) {
    double score = 0;
    final name = (member['name'] as String?) ?? '';
    final role = (member['role'] as String?) ?? '';
    final birthday = (member['birthday'] as String?) ?? '';
    final tags = List<String>.from(member['tags'] as List? ?? []);
    final facts = List<String>.from(member['facts'] as List? ?? []);

    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (name.contains(token)) score += 12;
      if (role.contains(token)) score += 5;
      // 概念匹配：查询词暗示生日
      if (_matchesConcept(token, ['生日', '出生']) && birthday.isNotEmpty) {
        score += 6;
      }
      for (final tag in tags) {
        if (tag.contains(token) || token.contains(tag)) score += 5;
      }
      for (final fact in facts) {
        if (fact.contains(token)) score += 2;
      }
    }

    if (score == 0) return null;
    return _ScoredEntry(member, score, {});
  }

  _ScoredEntry? _scoreFact(Map<String, dynamic> fact, List<String> tokens) {
    double score = 0;
    final title = (fact['title'] as String?) ?? '';
    final content = (fact['content'] as String?) ?? '';
    final tags = List<String>.from(fact['tags'] as List? ?? []);

    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (title.contains(token)) score += 8;
      if (content.contains(token)) score += 3;
      for (final tag in tags) {
        if (tag.contains(token) || token.contains(tag)) score += 5;
      }
    }

    if (score == 0) return null;
    return _ScoredEntry(fact, score, {});
  }

  // ---- 格式化 ----

  String _formatContext(List<_ScoredEntry> results) {
    final buf = StringBuffer();
    buf.writeln('以下是五月天相关的准确知识，请基于这些资料回答用户问题，务必引用准确的歌词：');
    buf.writeln();

    for (final r in results) {
      final entry = r.entry;
      final type = _getType(entry);

      if (type == 'song') {
        buf.writeln('【歌曲】${entry['title']}');
        buf.writeln('专辑：${entry['album']} (${entry['year']})');
        buf.writeln('主题：${(entry['tags'] as List).join('、')}');
        if (entry['description'] != null && (entry['description'] as String).isNotEmpty) {
          buf.writeln('简介：${entry['description']}');
        }
        buf.writeln('歌词：');
        for (final line in (entry['lyrics'] as List)) {
          buf.writeln('  "$line"');
        }
        buf.writeln();
      } else if (type == 'album') {
        buf.writeln('【专辑】${entry['name']} (${entry['year']})');
        buf.writeln('收录歌曲：${(entry['songs'] as List).join('、')}');
        buf.writeln('简介：${entry['description']}');
        buf.writeln();
      } else if (type == 'member') {
        buf.writeln('【成员】${entry['name']} — ${entry['role']}');
        if (entry['birthday'] != null) {
          buf.writeln('生日：${entry['birthday']}');
        }
        for (final fact in (entry['facts'] as List)) {
          buf.writeln('  · $fact');
        }
        buf.writeln();
      } else if (type == 'fact') {
        buf.writeln('【${entry['title']}】');
        buf.writeln(entry['content']);
        buf.writeln();
      }
    }

    buf.writeln('请基于以上真实歌词和资料回答，不要编造歌词内容。');
    return buf.toString();
  }

  String _getType(Map<String, dynamic> entry) {
    if (entry.containsKey('lyrics')) return 'song';
    if (entry.containsKey('songs')) return 'album';
    if (entry.containsKey('role')) return 'member';
    return 'fact';
  }
}
