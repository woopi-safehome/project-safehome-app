import { useCallback, useEffect, useRef, useState } from 'react';
import { Animated, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useLocalSearchParams, router } from 'expo-router';
import { getJob } from '@/services/api';
import { logger } from '@/services/logger';
import type { DeedJob } from '@/types/deed';

const POLL_INTERVAL_MS = 2000;
const MIN_MESSAGE_MS = 2000;

function getDetailedMessage(job: DeedJob | null): string {
  if (!job || job.status === 'PENDING') {
    return '파일을 받았어요\n잠시 후 분석을 시작할게요';
  }
  switch (job.step) {
    case 'PDF_PARSING':
      return '등기부등본의 내용을\n읽어오고 있어요';
    case 'LLM_ANALYSIS':
      return '소유권, 근저당, 가압류 등\n권리 관계를 꼼꼼히 살펴보고 있어요';
    case 'POST_PROCESSING':
      return '분석을 마무리하고\n안전 여부를 판단하고 있어요';
    default:
      return '분석을 준비하고 있어요\n잠시만 기다려주세요';
  }
}

export default function AnalyzingScreen() {
  const { jobId } = useLocalSearchParams<{ jobId: string }>();
  const [job, setJob] = useState<DeedJob | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [shouldNavigate, setShouldNavigate] = useState(false);

  // ── 펄스 애니메이션 ──
  const pulseScale = useRef(new Animated.Value(1)).current;
  const pulseOpacity = useRef(new Animated.Value(0.4)).current;

  useEffect(() => {
    Animated.loop(
      Animated.parallel([
        Animated.sequence([
          Animated.timing(pulseScale, { toValue: 1.4, duration: 1100, useNativeDriver: true }),
          Animated.timing(pulseScale, { toValue: 1, duration: 1100, useNativeDriver: true }),
        ]),
        Animated.sequence([
          Animated.timing(pulseOpacity, { toValue: 0, duration: 1100, useNativeDriver: true }),
          Animated.timing(pulseOpacity, { toValue: 0.4, duration: 1100, useNativeDriver: true }),
        ]),
      ]),
    ).start();
  }, [pulseOpacity, pulseScale]);

  // ── 메시지 전환 시스템 ──
  // 전환 중에 새 메시지가 오면 pendingMessageRef에 저장해두고,
  // 현재 메시지가 MIN_MESSAGE_MS 이상 표시된 뒤에 교체합니다.
  const fadeAnim = useRef(new Animated.Value(1)).current;
  const [displayedMessage, setDisplayedMessage] = useState(getDetailedMessage(null));
  const currentMessageRef = useRef(getDetailedMessage(null)); // 현재 화면에 표시 중인 메시지
  const pendingMessageRef = useRef<string | null>(null);       // 다음에 보여줄 메시지
  const messageShownAtRef = useRef(Date.now());                // 현재 메시지가 뜬 시각
  const isAnimatingRef = useRef(false);                        // 페이드 진행 중 여부
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null); // 대기 타이머

  const startTransition = useCallback((next: string) => {
    if (currentMessageRef.current === next) return;

    // 항상 최신 목표 메시지를 기록
    pendingMessageRef.current = next;

    // 페이드 중이거나 타이머가 이미 잡혀 있으면 대기만 하고 종료
    // → 현재 타이머/애니메이션이 끝날 때 pendingMessageRef를 꺼내 씀
    if (isAnimatingRef.current || timerRef.current !== null) return;

    const elapsed = Date.now() - messageShownAtRef.current;
    const delay = Math.max(0, MIN_MESSAGE_MS - elapsed);

    timerRef.current = setTimeout(() => {
      timerRef.current = null;
      const target = pendingMessageRef.current;
      pendingMessageRef.current = null;

      if (!target || currentMessageRef.current === target) return;

      isAnimatingRef.current = true;
      currentMessageRef.current = target;
      messageShownAtRef.current = Date.now();

      Animated.timing(fadeAnim, { toValue: 0, duration: 200, useNativeDriver: true }).start(() => {
        setDisplayedMessage(target);
        Animated.timing(fadeAnim, { toValue: 1, duration: 400, useNativeDriver: true }).start(() => {
          isAnimatingRef.current = false;
          // 애니메이션이 끝난 뒤 쌓인 요청이 있으면 이어서 처리
          if (pendingMessageRef.current && pendingMessageRef.current !== target) {
            startTransition(pendingMessageRef.current);
          }
        });
      });
    }, delay);
  }, [fadeAnim]);

  // job 변경 → 메시지 전환 요청
  useEffect(() => {
    startTransition(getDetailedMessage(job));
  }, [job, startTransition]);

  // ── 완료 후 최소 표시 시간 지키고 결과 페이지로 이동 ──
  useEffect(() => {
    if (!shouldNavigate) return;
    const elapsed = Date.now() - messageShownAtRef.current;
    const delay = Math.max(0, MIN_MESSAGE_MS - elapsed);
    const id = setTimeout(() => router.replace(`/result/${jobId}`), delay);
    return () => clearTimeout(id);
  }, [shouldNavigate, jobId]);

  // ── 폴링 ──
  useEffect(() => {
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout>;

    const poll = async () => {
      try {
        const data = await getJob(jobId);
        if (cancelled) return;

        if (data.status === 'COMPLETED') {
          setShouldNavigate(true);
          return;
        }

        setJob(data);

        if (data.status !== 'FAILED') {
          timer = setTimeout(poll, POLL_INTERVAL_MS);
        }
      } catch (e) {
        if (!cancelled) {
          logger.error('Analyzing', '상태 조회 실패', e, { jobId });
          setError(e instanceof Error ? e.message : '상태 조회에 실패했습니다.');
        }
      }
    };

    poll();
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [jobId]);

  // ── 에러 ──
  if (error || job?.status === 'FAILED') {
    const message = error ?? job?.description ?? '분석 중 오류가 발생했습니다.';
    return (
      <View style={styles.container}>
        <Text style={styles.errorIcon}>⚠️</Text>
        <Text style={styles.errorTitle}>분석 실패</Text>
        <Text style={styles.errorDesc}>{message}</Text>
        <TouchableOpacity style={styles.retryButton} onPress={() => router.replace('/upload')}>
          <Text style={styles.retryText}>다시 시도</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.loaderWrap}>
        <Animated.View
          style={[styles.pulseRing, { transform: [{ scale: pulseScale }], opacity: pulseOpacity }]}
        />
        <View style={styles.iconCircle}>
          <Text style={styles.iconText}>🔍</Text>
        </View>
      </View>

      <Text style={styles.title}>AI가 분석하고 있어요</Text>

      <Animated.Text style={[styles.statusMessage, { opacity: fadeAnim }]}>
        {displayedMessage}
      </Animated.Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
    gap: 20,
  },
  loaderWrap: {
    width: 100,
    height: 100,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  pulseRing: {
    position: 'absolute',
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#2563EB',
  },
  iconCircle: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#2563EB',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 12,
    elevation: 6,
  },
  iconText: {
    fontSize: 32,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: '#0F172A',
    textAlign: 'center',
  },
  statusMessage: {
    fontSize: 15,
    color: '#64748B',
    textAlign: 'center',
    lineHeight: 24,
    maxWidth: 280,
  },
  errorIcon: {
    fontSize: 52,
  },
  errorTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: '#0F172A',
  },
  errorDesc: {
    fontSize: 14,
    color: '#64748B',
    textAlign: 'center',
    lineHeight: 22,
    maxWidth: 280,
  },
  retryButton: {
    backgroundColor: '#2563EB',
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 12,
    marginTop: 4,
  },
  retryText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
});
