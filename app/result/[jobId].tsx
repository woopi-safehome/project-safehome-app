import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useLocalSearchParams, router } from 'expo-router';
import { getJob } from '@/services/api';
import type { ChecklistItem, DeedAnalysis, DeedJob, SafetyLevel } from '@/types/deed';

// ─── 안전 등급 메타데이터 ────────────────────────────────────────────
const SAFETY_META: Record<SafetyLevel, { label: string; icon: string; bg: string; text: string; border: string }> = {
  SAFE:    { label: '안전',    icon: '✅', bg: '#F0FDF4', text: '#15803D', border: '#86EFAC' },
  CAUTION: { label: '주의',    icon: '⚠️', bg: '#FFFBEB', text: '#B45309', border: '#FCD34D' },
  DANGER:  { label: '위험',    icon: '🚨', bg: '#FFF1F2', text: '#BE123C', border: '#FDA4AF' },
};

const CHECKLIST_META: Record<string, { color: string; badge: string }> = {
  '양호':   { color: '#15803D', badge: '#DCFCE7' },
  '주의':   { color: '#B45309', badge: '#FEF9C3' },
  '위험':   { color: '#BE123C', badge: '#FFE4E6' },
  '확인불가': { color: '#64748B', badge: '#F1F5F9' },
};

// ─── 메인 화면 ───────────────────────────────────────────────────────
export default function ResultScreen() {
  const { jobId } = useLocalSearchParams<{ jobId: string }>();
  const [job, setJob] = useState<DeedJob | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        const data = await getJob(jobId);
        setJob(data);
      } catch (e) {
        setError(e instanceof Error ? e.message : '조회에 실패했습니다.');
      }
    };
    load();
  }, [jobId]);

  // ── 로딩 ──
  if (!job) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color="#2563EB" />
        {error ? (
          <>
            <Text style={styles.stateTitle}>오류 발생</Text>
            <Text style={styles.stateDesc}>{error}</Text>
            <TouchableOpacity style={styles.retryButton} onPress={() => router.back()}>
              <Text style={styles.retryText}>다시 시도</Text>
            </TouchableOpacity>
          </>
        ) : (
          <>
            <Text style={styles.loadingTitle}>결과 불러오는 중...</Text>
          </>
        )}
      </View>
    );
  }

  // ── 오류 / FAILED ──
  if (job.status === 'FAILED') {
    return (
      <View style={styles.centered}>
        <Text style={styles.stateIcon}>⚠️</Text>
        <Text style={styles.stateTitle}>분석 실패</Text>
        <Text style={styles.stateDesc}>{job.description ?? '분석 중 오류가 발생했습니다.'}</Text>
        <TouchableOpacity style={styles.retryButton} onPress={() => router.back()}>
          <Text style={styles.retryText}>다시 시도</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const analysis: DeedAnalysis | null = job.result ?? null;

  if (!analysis) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color="#2563EB" />
        <Text style={styles.loadingTitle}>분석 중...</Text>
        <Text style={styles.loadingSubtitle}>AI가 권리 관계를 분석하고 있습니다</Text>
      </View>
    );
  }

  // ── 유효하지 않은 문서 ──
  if (!analysis.isValidDeed) {
    return (
      <View style={styles.centered}>
        <Text style={styles.stateIcon}>📋</Text>
        <Text style={styles.stateTitle}>등기부등본이 아닙니다</Text>
        <Text style={styles.stateDesc}>{analysis.reason ?? '유효한 등기부등본 파일을 업로드해주세요.'}</Text>
        <TouchableOpacity style={styles.retryButton} onPress={() => router.back()}>
          <Text style={styles.retryText}>다시 시도</Text>
        </TouchableOpacity>
      </View>
    );
  }

  // ── 정상 결과 ──
  const safetyLevel = analysis.safetyLevel!;
  const meta = SAFETY_META[safetyLevel];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* 헤더 */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.replace('/')} style={styles.backButton}>
          <Text style={styles.backText}>← 홈으로</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>분석 결과</Text>
        <View style={styles.backButton} />
      </View>

      {/* 안전 등급 배지 */}
      <View style={[styles.safetyCard, { backgroundColor: meta.bg, borderColor: meta.border }]}>
        <Text style={styles.safetyIcon}>{meta.icon}</Text>
        <Text style={[styles.safetyLabel, { color: meta.text }]}>{meta.label}</Text>
        <Text style={[styles.safetyLevel, { color: meta.text }]}>{safetyLevel}</Text>
      </View>

      {/* 부동산 기본 정보 */}
      {analysis.propertyInfo && (
        <Card title="🏠 부동산 기본 정보">
          <InfoRow label="주소" value={analysis.propertyInfo.address} />
          <InfoRow label="종류" value={analysis.propertyInfo.type} />
          <InfoRow label="면적" value={analysis.propertyInfo.area} />
          {analysis.propertyInfo.purpose && (
            <InfoRow label="용도" value={analysis.propertyInfo.purpose} />
          )}
          {analysis.propertyInfo.buildYear && (
            <InfoRow label="건축연도" value={analysis.propertyInfo.buildYear} />
          )}
        </Card>
      )}

      {/* 소유권 정보 */}
      {analysis.ownershipInfo && (
        <Card title="👤 소유권 정보">
          <InfoRow label="소유자" value={analysis.ownershipInfo.currentOwner} />
          <InfoRow label="소유형태" value={analysis.ownershipInfo.ownerType} />
          {analysis.ownershipInfo.recentTransferDate && (
            <InfoRow label="최근 취득일" value={analysis.ownershipInfo.recentTransferDate} />
          )}
          {analysis.ownershipInfo.recentTransferCause && (
            <InfoRow label="취득 원인" value={analysis.ownershipInfo.recentTransferCause} />
          )}
          {analysis.ownershipInfo.frequentTransferWarning && (
            <View style={styles.warningBadge}>
              <Text style={styles.warningText}>⚠️ 단기간 잦은 소유권 이전 — 갭투자 의심 패턴</Text>
            </View>
          )}
        </Card>
      )}

      {/* 핵심 위험 사항 */}
      {analysis.keyRiskPoints && analysis.keyRiskPoints.length > 0 && (
        <Card title="⚠️ 핵심 위험 사항">
          {analysis.keyRiskPoints.map((risk, i) => (
            <View key={i} style={styles.bulletRow}>
              <Text style={styles.bullet}>•</Text>
              <Text style={styles.bulletText}>{risk}</Text>
            </View>
          ))}
        </Card>
      )}

      {/* 안전 체크리스트 */}
      {analysis.safetyChecklist && analysis.safetyChecklist.length > 0 && (
        <Card title="✅ 안전 체크리스트">
          {analysis.safetyChecklist.map((item, i) => (
            <ChecklistRow key={i} item={item} />
          ))}
        </Card>
      )}

      {/* 종합 분석 */}
      {analysis.summary && (
        <Card title="📋 종합 분석">
          <Text style={styles.bodyText}>{analysis.summary}</Text>
        </Card>
      )}

      {/* 권고 사항 */}
      {analysis.recommendation && (
        <Card title="💡 권고 사항">
          <Text style={styles.bodyText}>{analysis.recommendation}</Text>
        </Card>
      )}

      {/* 하단 여백 */}
      <View style={{ height: 48 }} />
    </ScrollView>
  );
}

// ─── 하위 컴포넌트 ────────────────────────────────────────────────────
function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.card}>
      <Text style={styles.cardTitle}>{title}</Text>
      <View style={styles.cardBody}>{children}</View>
    </View>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue}>{value}</Text>
    </View>
  );
}

function ChecklistRow({ item }: { item: ChecklistItem }) {
  const meta = CHECKLIST_META[item.status] ?? CHECKLIST_META['확인불가'];
  return (
    <View style={styles.checklistRow}>
      <View style={styles.checklistTop}>
        <Text style={styles.checklistItem} numberOfLines={2}>{item.item}</Text>
        <View style={[styles.statusBadge, { backgroundColor: meta.badge }]}>
          <Text style={[styles.statusText, { color: meta.color }]}>{item.status}</Text>
        </View>
      </View>
      <Text style={styles.checklistDetail}>{item.detail}</Text>
    </View>
  );
}

// ─── 스타일 ───────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  content: {
    paddingBottom: 24,
  },
  centered: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
    gap: 12,
    backgroundColor: '#F8FAFC',
  },

  // ── 로딩 ──
  loadingTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: '#0F172A',
    marginTop: 8,
  },
  loadingSubtitle: {
    fontSize: 14,
    color: '#64748B',
    textAlign: 'center',
  },

  // ── 오류/무효 ──
  stateIcon: { fontSize: 52 },
  stateTitle: { fontSize: 20, fontWeight: '700', color: '#0F172A' },
  stateDesc: { fontSize: 14, color: '#64748B', textAlign: 'center', lineHeight: 22 },
  retryButton: {
    marginTop: 8,
    backgroundColor: '#2563EB',
    paddingHorizontal: 28,
    paddingVertical: 14,
    borderRadius: 10,
  },
  retryText: { color: '#fff', fontWeight: '700', fontSize: 16 },

  // ── 헤더 ──
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 56,
    paddingBottom: 16,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#E2E8F0',
  },
  backButton: { width: 60 },
  backText: { fontSize: 16, color: '#2563EB' },
  headerTitle: { fontSize: 18, fontWeight: '600', color: '#0F172A' },

  // ── 안전 등급 ──
  safetyCard: {
    margin: 16,
    borderRadius: 16,
    borderWidth: 1.5,
    paddingVertical: 28,
    alignItems: 'center',
    gap: 6,
  },
  safetyIcon: { fontSize: 44 },
  safetyLabel: { fontSize: 24, fontWeight: '800' },
  safetyLevel: { fontSize: 14, fontWeight: '600', opacity: 0.8 },

  // ── 카드 ──
  card: {
    backgroundColor: '#fff',
    marginHorizontal: 16,
    marginBottom: 12,
    borderRadius: 14,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 1,
    overflow: 'hidden',
  },
  cardTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: '#0F172A',
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: '#F1F5F9',
  },
  cardBody: {
    padding: 16,
    gap: 10,
  },

  // ── InfoRow ──
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 12,
  },
  infoLabel: {
    fontSize: 13,
    color: '#64748B',
    width: 80,
    flexShrink: 0,
  },
  infoValue: {
    fontSize: 13,
    color: '#0F172A',
    fontWeight: '500',
    flex: 1,
    textAlign: 'right',
  },

  // ── 경고 배지 ──
  warningBadge: {
    backgroundColor: '#FEF3C7',
    borderRadius: 8,
    padding: 10,
    marginTop: 4,
  },
  warningText: {
    fontSize: 13,
    color: '#92400E',
    fontWeight: '600',
  },

  // ── 불릿 리스트 ──
  bulletRow: {
    flexDirection: 'row',
    gap: 8,
    alignItems: 'flex-start',
  },
  bullet: { fontSize: 14, color: '#94A3B8', marginTop: 2 },
  bulletText: { flex: 1, fontSize: 14, color: '#1E293B', lineHeight: 22 },

  // ── 체크리스트 ──
  checklistRow: {
    gap: 6,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F1F5F9',
  },
  checklistTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 8,
  },
  checklistItem: {
    flex: 1,
    fontSize: 13,
    fontWeight: '600',
    color: '#0F172A',
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
  },
  statusText: {
    fontSize: 12,
    fontWeight: '700',
  },
  checklistDetail: {
    fontSize: 12,
    color: '#64748B',
    lineHeight: 18,
  },

  // ── 본문 ──
  bodyText: {
    fontSize: 14,
    color: '#334155',
    lineHeight: 24,
  },
});
