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

enum LeaseCheckItemPriority {
  @JsonValue('필수') required_,
  @JsonValue('권장') recommended,
  @JsonValue('참고') reference,
}

enum RiskSeverity {
  @JsonValue('HIGH') high,
  @JsonValue('MEDIUM') medium,
  @JsonValue('LOW') low,
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

// ─── Mortgage Detail ──────────────────────────────────────────────────────────

@freezed
class MortgageDetail with _$MortgageDetail {
  const factory MortgageDetail({
    required String creditor,
    required String maxClaimAmount,
    String? registrationDate,
    String? cancelDate,
    required bool isActive,
  }) = _MortgageDetail;

  factory MortgageDetail.fromJson(Map<String, dynamic> json) =>
      _$MortgageDetailFromJson(json);
}

// ─── Mortgage Info ────────────────────────────────────────────────────────────

@freezed
class MortgageInfo with _$MortgageInfo {
  const factory MortgageInfo({
    required int totalCount,
    required int activeCount,
    required String totalMaxClaimAmount,
    String? riskComment,
    @Default([]) List<MortgageDetail> details,
  }) = _MortgageInfo;

  factory MortgageInfo.fromJson(Map<String, dynamic> json) =>
      _$MortgageInfoFromJson(json);
}

// ─── Other Right ─────────────────────────────────────────────────────────────

@freezed
class OtherRight with _$OtherRight {
  const factory OtherRight({
    required String type,
    required String holder,
    String? amount,
    String? period,
    String? registrationDate,
    String? tenantImpact,
  }) = _OtherRight;

  factory OtherRight.fromJson(Map<String, dynamic> json) =>
      _$OtherRightFromJson(json);
}

// ─── Legal Risk ───────────────────────────────────────────────────────────────

@freezed
class LegalRisk with _$LegalRisk {
  const factory LegalRisk({
    required String type,
    required String claimant,
    String? amount,
    String? registrationDate,
    RiskSeverity? severity,
    String? description,
  }) = _LegalRisk;

  factory LegalRisk.fromJson(Map<String, dynamic> json) =>
      _$LegalRiskFromJson(json);
}

// ─── Checklist Item ───────────────────────────────────────────────────────────

@freezed
class ChecklistItem with _$ChecklistItem {
  const factory ChecklistItem({
    required String category,
    required String item,
    required ChecklistStatus status,
    required String detail,
  }) = _ChecklistItem;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemFromJson(json);
}

// ─── Lease Check Item ─────────────────────────────────────────────────────────

@freezed
class LeaseCheckItem with _$LeaseCheckItem {
  const factory LeaseCheckItem({
    required String category,
    required String title,
    required String description,
    required LeaseCheckItemPriority priority,
  }) = _LeaseCheckItem;

  factory LeaseCheckItem.fromJson(Map<String, dynamic> json) =>
      _$LeaseCheckItemFromJson(json);
}

// ─── Lease Specific Analysis ─────────────────────────────────────────────────

@freezed
class LeaseSpecificAnalysis with _$LeaseSpecificAnalysis {
  const factory LeaseSpecificAnalysis({
    required String leaseType,
    required String summary,
    @Default([]) List<LeaseCheckItem> checkItems,
  }) = _LeaseSpecificAnalysis;

  factory LeaseSpecificAnalysis.fromJson(Map<String, dynamic> json) =>
      _$LeaseSpecificAnalysisFromJson(json);
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
    PropertyInfo? propertyInfo,
    OwnershipInfo? ownershipInfo,
    MortgageInfo? mortgageInfo,
    @Default([]) List<OtherRight> otherRights,
    @Default([]) List<LegalRisk> legalRisks,
    @Default([]) List<ChecklistItem> safetyChecklist,
    @Default([]) List<String> keyRiskPoints,
    String? overallRiskSummary,
    LeaseSpecificAnalysis? leaseSpecificAnalysis,
    String? recommendation,
    String? summary,
  }) = _DeedAnalysis;

  factory DeedAnalysis.fromJson(Map<String, dynamic> json) =>
      _$DeedAnalysisFromJson(json);
}
