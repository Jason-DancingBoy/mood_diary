class TokenUsage {
  final String source;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final DateTime timestamp;

  TokenUsage({
    required this.source,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.timestamp,
  });

  factory TokenUsage.fromMap(Map<String, dynamic> map) {
    return TokenUsage(
      source: map['source'] as String,
      model: map['model'] as String,
      promptTokens: map['promptTokens'] as int,
      completionTokens: map['completionTokens'] as int,
      totalTokens: map['totalTokens'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'model': model,
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'totalTokens': totalTokens,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
