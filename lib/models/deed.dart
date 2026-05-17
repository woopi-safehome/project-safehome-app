import 'package:freezed_annotation/freezed_annotation.dart';

part 'deed.freezed.dart';
part 'deed.g.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum SafetyLevel {
  @JsonValue('SAFE') safe,
  @JsonValue('CAUTION') caution,
  @JsonValue('DANGER') danger,
}

enum JobStatus {
  @JsonValue('PENDING') pending,
  @JsonValue('IN_PROGRESS') inProgress,
  @JsonValue('COMPLETED') completed,
  @JsonValue('FAILED') failed,
}

enum AnalysisStep {
  @JsonValue('PDF_PARSING') pdfParsing,
  @JsonValue('LLM_ANALYSIS') llmAnalysis,
  @JsonValue('POST_PROCESSING') postProcessing,
}

enum ChecklistStatus {
  @JsonValue('양호') good,
  @JsonValue('주의') caution,
  @JsonValue('위험') danger,
  @JsonValue('확인불가') unknown,
}

enum LeaseType {
  @JsonValue('전세') jeonse,
  @JsonValue('월세') wolse,
}

enum RecommendationPriority {
  @JsonValue('필수') required_,
  @JsonValue('권장') recommended,
  @JsonValue('참고') reference,
}

// ─── SSE Event ───────────────────────────────────────────────────────────────

@freezed
class SseEvent with _$SseEvent {
  const factory SseEvent({
    required String jobId,
    required JobStatus status,
    AnalysisStep? step,
    required String message,
    required String timestamp,
  }) = _SseEvent;

  factory SseEvent.fromJson(Map<String, dynamic> json) =>
      _$SseEventFromJson(json);
}

// ─── Job Entity ───────────────────────────────────────────────────────────────

@freezed
class DeedJob with _$DeedJob {
  const factory DeedJob({
    required String jobId,
    required JobStatus status,
    required String fileName,
    required int fileSize,
    AnalysisStep? step,
    String? description,
    DeedAnalysis? result,
  }) = _DeedJob;

  factory DeedJob.fromJson(Map<String, dynamic> json) =>
      _$DeedJobFromJson(json);
}

// ─── Property Info ────────────────────────────────────────────────────────────

@freezed
class PropertyInfo with _$PropertyInfo {
  const factory PropertyInfo({
    required String address,
    required String type,
    required String area,
    String? structure,
    String? purpose,
    String? buildYear,
  }) = _PropertyInfo;

  factory PropertyInfo.fromJson(Map<String, dynamic> json) =>
      _$PropertyInfoFromJson(json);
}

// ─── Ownership Info ───────────────────────────────────────────────────────────

@freezed
class OwnershipInfo with _$OwnershipInfo {
  const factory OwnershipInfo({
    required String currentOwner,
    required String ownerType,
    String? shareRatio,
    String? recentTransferDate,
    String? recentTransferCause,
    int? transferCount,
    @Default(false) bool frequentTransferWarning,
  }) = _OwnershipInfo;

  factory OwnershipInfo.fromJson(Map<String, dynamic> json) =>
      _$OwnershipInfoFromJson(json);
}

// ─── Checklist Analysis ───────────────────────────────────────────────────────

@freezed
class ChecklistAnalysis with _$ChecklistAnalysis {
  const factory ChecklistAnalysis({
    required String findings,
    required String leaseImpact,
  }) = _ChecklistAnalysis;

  factory ChecklistAnalysis.fromJson(Map<String, dynamic> json) =>
      _$ChecklistAnalysisFromJson(json);
}

// ─── Checklist Item ───────────────────────────────────────────────────────────

@freezed
class ChecklistItem with _$ChecklistItem {
  const factory ChecklistItem({
    required String id,
    required String category,
    required String item,
    required ChecklistStatus status,
    required String detail,
    ChecklistAnalysis? analysis,
  }) = _ChecklistItem;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemFromJson(json);
}

// ─── Risk Summary ─────────────────────────────────────────────────────────────

@freezed
class RiskSummary with _$RiskSummary {
  const factory RiskSummary({
    required String leaseType,
    required String level,
    required String content,
  }) = _RiskSummary;

  factory RiskSummary.fromJson(Map<String, dynamic> json) =>
      _$RiskSummaryFromJson(json);
}

// ─── Recommendation ───────────────────────────────────────────────────────────

@freezed
class Recommendation with _$Recommendation {
  const factory Recommendation({
    required RecommendationPriority priority,
    required String title,
    required String description,
  }) = _Recommendation;

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);
}

// ─── Reference Item ───────────────────────────────────────────────────────────

@freezed
class ReferenceItem with _$ReferenceItem {
  const factory ReferenceItem({
    required String source,
    required String article,
    required String title,
    required String content,
    required String riskContext,
    @Default([]) List<String> tags,
  }) = _ReferenceItem;

  factory ReferenceItem.fromJson(Map<String, dynamic> json) =>
      _$ReferenceItemFromJson(json);
}

// ─── References ───────────────────────────────────────────────────────────────

@freezed
class References with _$References {
  const factory References({
    @Default([]) List<ReferenceItem> laws,
    @Default([]) List<ReferenceItem> cases,
  }) = _References;

  factory References.fromJson(Map<String, dynamic> json) =>
      _$ReferencesFromJson(json);
}

// ─── Job Summary (목록용) ──────────────────────────────────────────────────────

@freezed
class DeedJobSummary with _$DeedJobSummary {
  const factory DeedJobSummary({
    required String jobId,
    required String fileName,
    required int fileSize,
    required JobStatus status,
    SafetyLevel? safetyLevel,
    String? address,
    String? createdAt,
    String? leaseType,
  }) = _DeedJobSummary;

  factory DeedJobSummary.fromJson(Map<String, dynamic> json) =>
      _$DeedJobSummaryFromJson(json);
}

class DeedJobsPage {
  final List<DeedJobSummary> items;
  final bool hasNext;
  final int totalElements;

  const DeedJobsPage({
    required this.items,
    required this.hasNext,
    required this.totalElements,
  });
}

// ─── Deed Analysis ────────────────────────────────────────────────────────────

@freezed
class DeedAnalysis with _$DeedAnalysis {
  const factory DeedAnalysis({
    required bool isValidDeed,
    String? reason,
    SafetyLevel? safetyLevel,
    String? analysisSummary,
    PropertyInfo? propertyInfo,
    OwnershipInfo? ownershipInfo,
    @Default([]) List<ChecklistItem> checklist,
    RiskSummary? riskSummary,
    String? overallSummary,
    @Default([]) List<Recommendation> recommendations,
    References? references,
  }) = _DeedAnalysis;

  factory DeedAnalysis.fromJson(Map<String, dynamic> json) =>
      _$DeedAnalysisFromJson(json);
}
