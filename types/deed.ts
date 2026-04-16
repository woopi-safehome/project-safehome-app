export type SafetyLevel = 'SAFE' | 'CAUTION' | 'DANGER';
export type JobStatus = 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED';
export type ChecklistStatus = '양호' | '주의' | '위험' | '확인불가';
export type RiskSeverity = 'HIGH' | 'MEDIUM' | 'LOW';
export type AnalysisStep = 'PDF_PARSING' | 'LLM_ANALYSIS' | 'POST_PROCESSING';

export interface ApiResponse<T> {
  type: 'success' | 'error';
  data?: T;
  message?: string;
  code?: string;
}

export interface SseEvent {
  jobId: string;
  status: JobStatus;
  step: AnalysisStep | null;
  message: string;
  timestamp: string;
}

export interface DeedJob {
  jobId: string;
  status: JobStatus;
  fileName: string;
  fileSize: number;
  step?: AnalysisStep;
  description?: string;
  result?: DeedAnalysis; // @JsonRawValue로 내려오므로 이미 파싱된 객체
}

export interface DeedAnalysis {
  isValidDeed: boolean;
  reason?: string;
  safetyLevel?: SafetyLevel;
  propertyInfo?: PropertyInfo;
  ownershipInfo?: OwnershipInfo;
  mortgageInfo?: MortgageInfo;
  otherRights?: OtherRight[];
  legalRisks?: LegalRisk[];
  safetyChecklist?: ChecklistItem[];
  keyRiskPoints?: string[];
  recommendation?: string;
  summary?: string;
}

export interface PropertyInfo {
  address: string;
  type: string;
  area: string;
  structure?: string;
  purpose?: string;
  buildYear?: string | null;
}

export interface OwnershipInfo {
  currentOwner: string;
  ownerType: string;
  shareRatio?: string | null;
  recentTransferDate?: string;
  recentTransferCause?: string;
  transferCount?: number;
  frequentTransferWarning?: boolean;
}

export interface MortgageInfo {
  totalCount: number;
  activeCount: number;
  totalMaxClaimAmount: string;
  riskComment?: string;
  details?: MortgageDetail[];
}

export interface MortgageDetail {
  rank: number;
  type: string;
  creditor: string;
  maxClaimAmount: string;
  registrationDate: string;
  isActive: boolean;
  note?: string | null;
}

export interface OtherRight {
  type: string;
  holder: string;
  amount?: string | null;
  period?: string | null;
  registrationDate: string;
  tenantImpact: string;
}

export interface LegalRisk {
  type: string;
  claimant: string;
  amount?: string | null;
  registrationDate: string;
  severity: RiskSeverity;
  description: string;
}

export interface ChecklistItem {
  category: string;
  item: string;
  status: ChecklistStatus;
  detail: string;
}
