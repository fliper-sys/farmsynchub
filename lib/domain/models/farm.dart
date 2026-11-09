/// Farmer category enumeration.
enum FarmerCategory {
  subsistence,
  semiCommercial,
  marketOriented,
}

/// Soil type enumeration.
enum SoilType {
  clay,
  sandy,
  loamy,
  silt,
}

/// Water source enumeration.
enum WaterSource {
  rainfall,
  borehole,
  river,
  dam,
  irrigation,
}

/// Farm operation type enumeration.
enum FarmType {
  crop,
  livestock,
  greenhouse,
  combined,
}

/// Farm workspace role enumeration.
enum FarmWorkspaceRole {
  owner,
  coOwner,
  manager,
  supervisor,
  worker,
  partner,
  viewer,
}

/// Finance access level for a farm member.
enum FarmFinanceAccess {
  none,
  viewOnly,
  recordOnly,
  manage,
}

/// Farm task lifecycle state.
enum FarmTaskStatus {
  open,
  inProgress,
  blocked,
  done,
}

/// Audience for activity updates.
enum FarmActivityAudience {
  owners,
  workspace,
  selectedMembers,
}

class FarmDocumentRecord {
  const FarmDocumentRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.reference,
    required this.notes,
    required this.createdAt,
    this.fileBase64 = '',
    this.fileName = '',
    this.mimeType = '',
  });

  final String id;
  final String title;
  final String type;
  final String reference;
  final String notes;
  final DateTime createdAt;

  /// Base64-encoded bytes of an attached file, if the farmer uploaded one
  /// instead of (or alongside) a plain storage reference. Empty when no
  /// file is attached.
  final String fileBase64;
  final String fileName;
  final String mimeType;

  bool get hasAttachedFile => fileBase64.isNotEmpty;

  FarmDocumentRecord copyWith({
    String? id,
    String? title,
    String? type,
    String? reference,
    String? notes,
    DateTime? createdAt,
    String? fileBase64,
    String? fileName,
    String? mimeType,
  }) {
    return FarmDocumentRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      fileBase64: fileBase64 ?? this.fileBase64,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'type': type,
        'reference': reference,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'fileBase64': fileBase64,
        'fileName': fileName,
        'mimeType': mimeType,
      };

  factory FarmDocumentRecord.fromJson(Map<String, dynamic> json) {
    return FarmDocumentRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'Document',
      reference: json['reference'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      fileBase64: json['fileBase64'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
    );
  }
}

class FarmWorkspaceMember {
  const FarmWorkspaceMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.allowedFarmIds,
    required this.financeAccess,
    required this.createdAt,
    required this.updatedAt,
    this.phone = '',
    this.canManageTasks = false,
    this.canManageSchedule = false,
    this.canPostUpdates = false,
    this.canViewActivityLog = true,
    this.isActive = true,
    this.lastSeenAt,
    this.allowedCropIds = const <String>[],
    this.allowedLivestockIds = const <String>[],
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final FarmWorkspaceRole role;
  final List<String> allowedFarmIds;
  final FarmFinanceAccess financeAccess;
  final bool canManageTasks;
  final bool canManageSchedule;
  final bool canPostUpdates;
  final bool canViewActivityLog;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSeenAt;

  /// Crop record ids this member may access within their allowed farms.
  /// Empty means unrestricted (every crop on those farms is visible).
  final List<String> allowedCropIds;

  /// Livestock record ids this member may access within their allowed
  /// farms. Empty means unrestricted (every group on those farms is
  /// visible).
  final List<String> allowedLivestockIds;

  /// Whether this member's crop/livestock access is scoped to specific
  /// records rather than everything on their allowed farms.
  bool get hasScopedRecordAccess =>
      allowedCropIds.isNotEmpty || allowedLivestockIds.isNotEmpty;

  String get roleLabel => switch (role) {
        FarmWorkspaceRole.owner => 'Owner',
        FarmWorkspaceRole.coOwner => 'Co-owner',
        FarmWorkspaceRole.manager => 'Manager',
        FarmWorkspaceRole.supervisor => 'Supervisor',
        FarmWorkspaceRole.worker => 'Worker',
        FarmWorkspaceRole.partner => 'Partner',
        FarmWorkspaceRole.viewer => 'Viewer',
      };

  String get financeAccessLabel => switch (financeAccess) {
        FarmFinanceAccess.none => 'No finance access',
        FarmFinanceAccess.viewOnly => 'View finance',
        FarmFinanceAccess.recordOnly => 'Record finance',
        FarmFinanceAccess.manage => 'Manage finance',
      };

  FarmWorkspaceMember copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    FarmWorkspaceRole? role,
    List<String>? allowedFarmIds,
    FarmFinanceAccess? financeAccess,
    bool? canManageTasks,
    bool? canManageSchedule,
    bool? canPostUpdates,
    bool? canViewActivityLog,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeenAt,
    bool clearLastSeenAt = false,
    List<String>? allowedCropIds,
    List<String>? allowedLivestockIds,
  }) {
    return FarmWorkspaceMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      allowedFarmIds: allowedFarmIds ?? this.allowedFarmIds,
      financeAccess: financeAccess ?? this.financeAccess,
      canManageTasks: canManageTasks ?? this.canManageTasks,
      canManageSchedule: canManageSchedule ?? this.canManageSchedule,
      canPostUpdates: canPostUpdates ?? this.canPostUpdates,
      canViewActivityLog: canViewActivityLog ?? this.canViewActivityLog,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: clearLastSeenAt ? null : lastSeenAt ?? this.lastSeenAt,
      allowedCropIds: allowedCropIds ?? this.allowedCropIds,
      allowedLivestockIds: allowedLivestockIds ?? this.allowedLivestockIds,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'allowedFarmIds': allowedFarmIds,
        'financeAccess': financeAccess.name,
        'canManageTasks': canManageTasks,
        'canManageSchedule': canManageSchedule,
        'canPostUpdates': canPostUpdates,
        'canViewActivityLog': canViewActivityLog,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastSeenAt': lastSeenAt?.toIso8601String(),
        'allowedCropIds': allowedCropIds,
        'allowedLivestockIds': allowedLivestockIds,
      };

  factory FarmWorkspaceMember.fromJson(Map<String, dynamic> json) {
    return FarmWorkspaceMember(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: FarmWorkspaceRole.values.firstWhere(
        (FarmWorkspaceRole value) => value.name == json['role'],
        orElse: () => FarmWorkspaceRole.worker,
      ),
      allowedFarmIds: _stringList(json['allowedFarmIds']),
      financeAccess: FarmFinanceAccess.values.firstWhere(
        (FarmFinanceAccess value) => value.name == json['financeAccess'],
        orElse: () => FarmFinanceAccess.none,
      ),
      canManageTasks: json['canManageTasks'] as bool? ?? false,
      canManageSchedule: json['canManageSchedule'] as bool? ?? false,
      canPostUpdates: json['canPostUpdates'] as bool? ?? false,
      canViewActivityLog: json['canViewActivityLog'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      lastSeenAt: DateTime.tryParse(json['lastSeenAt'] as String? ?? ''),
      allowedCropIds: _stringList(json['allowedCropIds']),
      allowedLivestockIds: _stringList(json['allowedLivestockIds']),
    );
  }
}

class FarmWorkspaceTask {
  const FarmWorkspaceTask({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.details = '',
    this.assigneeId = '',
    this.assigneeName = '',
    this.assigneeRole = FarmWorkspaceRole.worker,
    this.status = FarmTaskStatus.open,
    this.reminderEnabled = true,
    this.reminderLeadMinutes = 60,
    this.completedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  final String id;
  final String title;
  final String details;
  final String assigneeId;
  final String assigneeName;
  final FarmWorkspaceRole assigneeRole;
  final DateTime dueAt;
  final FarmTaskStatus status;
  final bool reminderEnabled;
  final int reminderLeadMinutes;
  final DateTime? completedAt;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == FarmTaskStatus.done;

  String get statusLabel => switch (status) {
        FarmTaskStatus.open => 'Open',
        FarmTaskStatus.inProgress => 'In progress',
        FarmTaskStatus.blocked => 'Blocked',
        FarmTaskStatus.done => 'Done',
      };

  FarmWorkspaceTask copyWith({
    String? id,
    String? title,
    String? details,
    String? assigneeId,
    String? assigneeName,
    FarmWorkspaceRole? assigneeRole,
    DateTime? dueAt,
    FarmTaskStatus? status,
    bool? reminderEnabled,
    int? reminderLeadMinutes,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmWorkspaceTask(
      id: id ?? this.id,
      title: title ?? this.title,
      details: details ?? this.details,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      assigneeRole: assigneeRole ?? this.assigneeRole,
      dueAt: dueAt ?? this.dueAt,
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'details': details,
        'assigneeId': assigneeId,
        'assigneeName': assigneeName,
        'assigneeRole': assigneeRole.name,
        'dueAt': dueAt.toIso8601String(),
        'status': status.name,
        'reminderEnabled': reminderEnabled,
        'reminderLeadMinutes': reminderLeadMinutes,
        'completedAt': completedAt?.toIso8601String(),
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FarmWorkspaceTask.fromJson(Map<String, dynamic> json) {
    return FarmWorkspaceTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Farm task',
      details: json['details'] as String? ?? '',
      assigneeId: json['assigneeId'] as String? ?? '',
      assigneeName: json['assigneeName'] as String? ?? '',
      assigneeRole: FarmWorkspaceRole.values.firstWhere(
        (FarmWorkspaceRole value) => value.name == json['assigneeRole'],
        orElse: () => FarmWorkspaceRole.worker,
      ),
      dueAt:
          DateTime.tryParse(json['dueAt'] as String? ?? '') ?? DateTime.now(),
      status: FarmTaskStatus.values.firstWhere(
        (FarmTaskStatus value) => value.name == json['status'],
        orElse: () => FarmTaskStatus.open,
      ),
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      reminderLeadMinutes: (json['reminderLeadMinutes'] as num?)?.toInt() ?? 60,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class FarmActivityRecord {
  const FarmActivityRecord({
    required this.id,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.detail,
    required this.audience,
    required this.createdAt,
    this.relatedTaskId = '',
    this.relatedMemberId = '',
    this.sentToOwners = true,
  });

  final String id;
  final String actorName;
  final FarmWorkspaceRole actorRole;
  final String action;
  final String detail;
  final FarmActivityAudience audience;
  final String relatedTaskId;
  final String relatedMemberId;
  final bool sentToOwners;
  final DateTime createdAt;

  String get audienceLabel => switch (audience) {
        FarmActivityAudience.owners => 'Owners',
        FarmActivityAudience.workspace => 'Workspace',
        FarmActivityAudience.selectedMembers => 'Selected members',
      };

  String get actorLabel => '$actorName · ${_farmRoleLabel(actorRole)}';

  FarmActivityRecord copyWith({
    String? id,
    String? actorName,
    FarmWorkspaceRole? actorRole,
    String? action,
    String? detail,
    FarmActivityAudience? audience,
    String? relatedTaskId,
    String? relatedMemberId,
    bool? sentToOwners,
    DateTime? createdAt,
  }) {
    return FarmActivityRecord(
      id: id ?? this.id,
      actorName: actorName ?? this.actorName,
      actorRole: actorRole ?? this.actorRole,
      action: action ?? this.action,
      detail: detail ?? this.detail,
      audience: audience ?? this.audience,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
      relatedMemberId: relatedMemberId ?? this.relatedMemberId,
      sentToOwners: sentToOwners ?? this.sentToOwners,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'actorName': actorName,
        'actorRole': actorRole.name,
        'action': action,
        'detail': detail,
        'audience': audience.name,
        'relatedTaskId': relatedTaskId,
        'relatedMemberId': relatedMemberId,
        'sentToOwners': sentToOwners,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FarmActivityRecord.fromJson(Map<String, dynamic> json) {
    return FarmActivityRecord(
      id: json['id'] as String? ?? '',
      actorName: json['actorName'] as String? ?? '',
      actorRole: FarmWorkspaceRole.values.firstWhere(
        (FarmWorkspaceRole value) => value.name == json['actorRole'],
        orElse: () => FarmWorkspaceRole.worker,
      ),
      action: json['action'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      audience: FarmActivityAudience.values.firstWhere(
        (FarmActivityAudience value) => value.name == json['audience'],
        orElse: () => FarmActivityAudience.workspace,
      ),
      relatedTaskId: json['relatedTaskId'] as String? ?? '',
      relatedMemberId: json['relatedMemberId'] as String? ?? '',
      sentToOwners: json['sentToOwners'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Farm model representing a farmer's agricultural land.
class Farm {
  const Farm({
    required this.id,
    required this.name,
    required this.ward,
    required this.sizeHa,
    required this.farmType,
    required this.farmerCategory,
    required this.soilType,
    required this.waterSource,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    this.ownerUid = '',
    this.ownerEmail = '',
    this.ownerName = '',
    this.coverImageBase64 = '',
    this.notes = '',
    this.temperatureCelsius = 0,
    this.humidityPercent = 0,
    this.soilMoisturePercent = 0,
    this.precipitationMm = 0,
    this.latitude,
    this.longitude,
    this.greenhouseCount = 0,
    this.greenhouseAreaHa = 0,
    this.greenhouseCropType = 'mixedVegetables',
    this.cropCapacityHa = 0,
    this.livestockCapacity = 0,
    this.documents = const <FarmDocumentRecord>[],
    this.workspaceMembers = const <FarmWorkspaceMember>[],
    this.workspaceTasks = const <FarmWorkspaceTask>[],
    this.activityLog = const <FarmActivityRecord>[],
    this.workspaceNotes = '',
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String ward;
  final double sizeHa;
  final FarmType farmType;
  final FarmerCategory farmerCategory;
  final SoilType soilType;
  final WaterSource waterSource;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String ownerUid;
  final String ownerEmail;
  final String ownerName;
  final String coverImageBase64;
  final String notes;
  final double temperatureCelsius;
  final double humidityPercent;
  final double soilMoisturePercent;
  final double precipitationMm;
  final double? latitude;
  final double? longitude;
  final int greenhouseCount;
  final double greenhouseAreaHa;

  /// Stores a [GreenhouseCropType] enum name (see
  /// core/services/greenhouse_planner_service.dart) - kept as a plain
  /// string here so the domain model doesn't depend on a service layer.
  final String greenhouseCropType;
  final double cropCapacityHa;
  final int livestockCapacity;
  final List<FarmDocumentRecord> documents;
  final List<FarmWorkspaceMember> workspaceMembers;
  final List<FarmWorkspaceTask> workspaceTasks;
  final List<FarmActivityRecord> activityLog;
  final String workspaceNotes;
  final bool isFavorite;

  bool get supportsCrops => <FarmType>[
        FarmType.crop,
        FarmType.greenhouse,
        FarmType.combined
      ].contains(farmType);
  bool get supportsLivestock =>
      <FarmType>[FarmType.livestock, FarmType.combined].contains(farmType);
  bool get supportsGreenhouse =>
      <FarmType>[FarmType.greenhouse, FarmType.combined].contains(farmType);
  int get ownerCount => workspaceMembers
      .where((FarmWorkspaceMember item) => <FarmWorkspaceRole>[
            FarmWorkspaceRole.owner,
            FarmWorkspaceRole.coOwner
          ].contains(item.role))
      .length;
  int get openWorkspaceTaskCount => workspaceTasks
      .where((FarmWorkspaceTask item) => !item.isCompleted)
      .length;
  int get financeEnabledMemberCount => workspaceMembers
      .where((FarmWorkspaceMember item) =>
          item.financeAccess != FarmFinanceAccess.none)
      .length;

  /// Denormalized workspace-member uids, kept in sync with [workspaceMembers]
  /// on every serialize. Lets Firestore query "farms I can access" with a
  /// single array-contains clause instead of downloading every farm in the
  /// collection and filtering client-side.
  List<String> get memberUids => workspaceMembers
      .map((FarmWorkspaceMember member) => member.id.trim())
      .where((String id) => id.isNotEmpty)
      .toList(growable: false);

  Farm copyWith({
    String? id,
    String? name,
    String? ward,
    double? sizeHa,
    FarmType? farmType,
    FarmerCategory? farmerCategory,
    SoilType? soilType,
    WaterSource? waterSource,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? ownerUid,
    String? ownerEmail,
    String? ownerName,
    String? coverImageBase64,
    String? notes,
    double? temperatureCelsius,
    double? humidityPercent,
    double? soilMoisturePercent,
    double? precipitationMm,
    double? latitude,
    double? longitude,
    int? greenhouseCount,
    double? greenhouseAreaHa,
    String? greenhouseCropType,
    double? cropCapacityHa,
    int? livestockCapacity,
    List<FarmDocumentRecord>? documents,
    List<FarmWorkspaceMember>? workspaceMembers,
    List<FarmWorkspaceTask>? workspaceTasks,
    List<FarmActivityRecord>? activityLog,
    String? workspaceNotes,
    bool? isFavorite,
  }) {
    return Farm(
      id: id ?? this.id,
      name: name ?? this.name,
      ward: ward ?? this.ward,
      sizeHa: sizeHa ?? this.sizeHa,
      farmType: farmType ?? this.farmType,
      farmerCategory: farmerCategory ?? this.farmerCategory,
      soilType: soilType ?? this.soilType,
      waterSource: waterSource ?? this.waterSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerName: ownerName ?? this.ownerName,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      notes: notes ?? this.notes,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      soilMoisturePercent: soilMoisturePercent ?? this.soilMoisturePercent,
      precipitationMm: precipitationMm ?? this.precipitationMm,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      greenhouseCount: greenhouseCount ?? this.greenhouseCount,
      greenhouseAreaHa: greenhouseAreaHa ?? this.greenhouseAreaHa,
      greenhouseCropType: greenhouseCropType ?? this.greenhouseCropType,
      cropCapacityHa: cropCapacityHa ?? this.cropCapacityHa,
      livestockCapacity: livestockCapacity ?? this.livestockCapacity,
      documents: documents ?? this.documents,
      workspaceMembers: workspaceMembers ?? this.workspaceMembers,
      workspaceTasks: workspaceTasks ?? this.workspaceTasks,
      activityLog: activityLog ?? this.activityLog,
      workspaceNotes: workspaceNotes ?? this.workspaceNotes,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'ward': ward,
        'sizeHa': sizeHa,
        'farmType': farmType.name,
        'farmerCategory': farmerCategory.name,
        'soilType': soilType.name,
        'waterSource': waterSource.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
        'ownerUid': ownerUid,
        'ownerEmail': ownerEmail,
        'ownerName': ownerName,
        'coverImageBase64': coverImageBase64,
        'notes': notes,
        'temperatureCelsius': temperatureCelsius,
        'humidityPercent': humidityPercent,
        'soilMoisturePercent': soilMoisturePercent,
        'precipitationMm': precipitationMm,
        'latitude': latitude,
        'longitude': longitude,
        'greenhouseCount': greenhouseCount,
        'greenhouseAreaHa': greenhouseAreaHa,
        'greenhouseCropType': greenhouseCropType,
        'cropCapacityHa': cropCapacityHa,
        'livestockCapacity': livestockCapacity,
        'documents':
            documents.map((FarmDocumentRecord item) => item.toJson()).toList(),
        'workspaceMembers': workspaceMembers
            .map((FarmWorkspaceMember item) => item.toJson())
            .toList(),
        'memberUids': memberUids,
        'workspaceTasks': workspaceTasks
            .map((FarmWorkspaceTask item) => item.toJson())
            .toList(),
        'activityLog': activityLog
            .map((FarmActivityRecord item) => item.toJson())
            .toList(),
        'workspaceNotes': workspaceNotes,
        'isFavorite': isFavorite,
      };

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        ward: json['ward'] as String? ?? '',
        sizeHa: (json['sizeHa'] as num?)?.toDouble() ?? 0,
        farmType: FarmType.values.firstWhere(
          (FarmType value) => value.name == json['farmType'],
          orElse: () => FarmType.combined,
        ),
        farmerCategory: FarmerCategory.values.firstWhere(
          (FarmerCategory value) => value.name == json['farmerCategory'],
          orElse: () => FarmerCategory.marketOriented,
        ),
        soilType: SoilType.values.firstWhere(
          (SoilType value) => value.name == json['soilType'],
          orElse: () => SoilType.loamy,
        ),
        waterSource: WaterSource.values.firstWhere(
          (WaterSource value) => value.name == json['waterSource'],
          orElse: () => WaterSource.rainfall,
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        isSynced: json['isSynced'] as bool? ?? false,
        ownerUid: json['ownerUid'] as String? ?? '',
        ownerEmail: json['ownerEmail'] as String? ?? '',
        ownerName: json['ownerName'] as String? ?? '',
        coverImageBase64: json['coverImageBase64'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        temperatureCelsius:
            (json['temperatureCelsius'] as num?)?.toDouble() ?? 0,
        humidityPercent: (json['humidityPercent'] as num?)?.toDouble() ?? 0,
        soilMoisturePercent:
            (json['soilMoisturePercent'] as num?)?.toDouble() ?? 0,
        precipitationMm: (json['precipitationMm'] as num?)?.toDouble() ?? 0,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        greenhouseCount: (json['greenhouseCount'] as num?)?.toInt() ?? 0,
        greenhouseAreaHa: (json['greenhouseAreaHa'] as num?)?.toDouble() ?? 0,
        greenhouseCropType:
            json['greenhouseCropType'] as String? ?? 'mixedVegetables',
        cropCapacityHa: (json['cropCapacityHa'] as num?)?.toDouble() ?? 0,
        livestockCapacity: (json['livestockCapacity'] as num?)?.toInt() ?? 0,
        documents: _jsonObjectList(json['documents'])
            .map(FarmDocumentRecord.fromJson)
            .toList(growable: false),
        workspaceMembers: _jsonObjectList(json['workspaceMembers'])
            .map(FarmWorkspaceMember.fromJson)
            .toList(growable: false),
        workspaceTasks: _jsonObjectList(json['workspaceTasks'])
            .map(FarmWorkspaceTask.fromJson)
            .toList(growable: false),
        activityLog: _jsonObjectList(json['activityLog'])
            .map(FarmActivityRecord.fromJson)
            .toList(growable: false),
        workspaceNotes: json['workspaceNotes'] as String? ?? '',
        isFavorite: json['isFavorite'] as bool? ?? false,
      );
}

List<Map<String, dynamic>> _jsonObjectList(Object? value) {
  if (value is! Iterable) {
    return <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((Map item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) {
    return <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

String _farmRoleLabel(FarmWorkspaceRole role) {
  switch (role) {
    case FarmWorkspaceRole.owner:
      return 'Owner';
    case FarmWorkspaceRole.coOwner:
      return 'Co-owner';
    case FarmWorkspaceRole.manager:
      return 'Manager';
    case FarmWorkspaceRole.supervisor:
      return 'Supervisor';
    case FarmWorkspaceRole.worker:
      return 'Worker';
    case FarmWorkspaceRole.partner:
      return 'Partner';
    case FarmWorkspaceRole.viewer:
      return 'Viewer';
  }
}
