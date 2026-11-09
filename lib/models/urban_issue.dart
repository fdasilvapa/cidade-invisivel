import 'issue_category.dart';

class UrbanIssue {
  final String id;
  final IssueCategory category;
  final String description;
  final double latitude;
  final double longitude;
  final Severity severity;
  final DateTime createdAt;
  final DateTime lastConfirmedAt;
  final int confirmationCount;
  final bool resolved;
  final bool mine;
  final bool isDemo;
  final bool flagged;

  /// Caminho da foto (não persistido: na web é uma URL temporária).
  final String? photoPath;

  /// Foto no servidor (caminho relativo, ex.: `/api/photos/ID`).
  final String? photoUrl;

  /// Confiança da classificação por IA (null enquanto não houver IA integrada).
  final double? aiConfidence;

  const UrbanIssue({
    required this.id,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.createdAt,
    required this.lastConfirmedAt,
    this.confirmationCount = 0,
    this.resolved = false,
    this.mine = false,
    this.isDemo = false,
    this.flagged = false,
    this.photoPath,
    this.photoUrl,
    this.aiConfidence,
  });

  /// RB12: sem confirmações da comunidade, o registro é marcado como incerto.
  bool get communityConfirmed => confirmationCount >= 2;

  UrbanIssue copyWith({
    int? confirmationCount,
    DateTime? lastConfirmedAt,
    bool? resolved,
    bool? flagged,
  }) =>
      UrbanIssue(
        id: id,
        category: category,
        description: description,
        latitude: latitude,
        longitude: longitude,
        severity: severity,
        createdAt: createdAt,
        lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
        confirmationCount: confirmationCount ?? this.confirmationCount,
        resolved: resolved ?? this.resolved,
        mine: mine,
        isDemo: isDemo,
        flagged: flagged ?? this.flagged,
        photoPath: photoPath,
        photoUrl: photoUrl,
        aiConfidence: aiConfidence,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity.name,
        'createdAt': createdAt.toIso8601String(),
        'lastConfirmedAt': lastConfirmedAt.toIso8601String(),
        'confirmationCount': confirmationCount,
        'resolved': resolved,
        'mine': mine,
        'isDemo': isDemo,
        'flagged': flagged,
        'aiConfidence': aiConfidence,
      };

  factory UrbanIssue.fromJson(Map<String, dynamic> j) => UrbanIssue(
        id: j['id'] as String,
        category: IssueCategory.fromName(j['category'] as String?),
        description: (j['description'] as String?) ?? '',
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        severity: Severity.fromName(j['severity'] as String?),
        createdAt: DateTime.parse(j['createdAt'] as String),
        lastConfirmedAt: DateTime.parse(j['lastConfirmedAt'] as String),
        confirmationCount: (j['confirmationCount'] as num?)?.toInt() ?? 0,
        resolved: (j['resolved'] as bool?) ?? false,
        mine: (j['mine'] as bool?) ?? false,
        isDemo: (j['isDemo'] as bool?) ?? false,
        flagged: (j['flagged'] as bool?) ?? false,
        photoUrl: j['photoUrl'] as String?,
        aiConfidence: (j['aiConfidence'] as num?)?.toDouble(),
      );
}
