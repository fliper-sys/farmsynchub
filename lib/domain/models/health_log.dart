/// Health log type enumeration.
enum HealthLogType {
  vaccination,
  treatment,
  checkup,
  birth,
  death,
}

/// Health log status enumeration.
enum HealthLogStatus {
  scheduled,
  done,
  overdue,
}

/// Health log model representing health events for livestock.
class HealthLog {
  const HealthLog({
    required this.id,
    required this.livestockId,
    required this.logType,
    required this.title,
    required this.description,
    required this.scheduledDate,
    required this.completedDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
  });

  final String id;
  final String livestockId;
  final HealthLogType logType;
  final String title;
  final String description;
  final DateTime scheduledDate;
  final DateTime completedDate;
  final HealthLogStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  Map<String, dynamic> toJson() => {
        'id': id,
        'livestockId': livestockId,
        'logType': logType.name,
        'title': title,
        'description': description,
        'scheduledDate': scheduledDate.toIso8601String(),
        'completedDate': completedDate.toIso8601String(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
      };

  factory HealthLog.fromJson(Map<String, dynamic> json) => HealthLog(
        id: json['id'] as String,
        livestockId: json['livestockId'] as String,
        logType: HealthLogType.values.firstWhere(
          (e) => e.name == json['logType'],
        ),
        title: json['title'] as String,
        description: json['description'] as String,
        scheduledDate: DateTime.parse(json['scheduledDate'] as String),
        completedDate: DateTime.parse(json['completedDate'] as String),
        status: HealthLogStatus.values.firstWhere(
          (e) => e.name == json['status'],
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isSynced: json['isSynced'] as bool,
      );
}