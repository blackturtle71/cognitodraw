class DrawingAssessment {
  const DrawingAssessment({
    required this.label,
    required this.score,
    required this.modelVersion,
    required this.preprocessingVersion,
    required this.inputFingerprint,
    required this.assessedAt,
  });

  final int label;
  final double score;
  final String modelVersion;
  final String preprocessingVersion;
  final String inputFingerprint;
  final String assessedAt;

  factory DrawingAssessment.fromMap(Map<String, Object?> map) =>
      DrawingAssessment(
        label: map['label'] as int,
        score: (map['score'] as num).toDouble(),
        modelVersion: map['modelVersion'] as String,
        preprocessingVersion: map['preprocessingVersion'] as String,
        inputFingerprint: map['inputFingerprint'] as String,
        assessedAt: map['assessedAt'] as String,
      );

  Map<String, Object?> toMap() => {
    'label': label,
    'score': score,
    'modelVersion': modelVersion,
    'preprocessingVersion': preprocessingVersion,
    'inputFingerprint': inputFingerprint,
    'assessedAt': assessedAt,
  };
}
