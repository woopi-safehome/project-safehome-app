import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { router } from 'expo-router';
import * as DocumentPicker from 'expo-document-picker';
import { analyzeDeed } from '@/services/api';
import type { SseEvent } from '@/types/deed';

export default function UploadScreen() {
  const [selectedFile, setSelectedFile] = useState<DocumentPicker.DocumentPickerAsset | null>(null);
  const [analyzing, setAnalyzing] = useState(false);
  const [progressMessage, setProgressMessage] = useState('');
  const [pendingJobId, setPendingJobId] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    return () => {
      abortRef.current?.abort();
    };
  }, []);

  const handlePickDocument = async () => {
    const result = await DocumentPicker.getDocumentAsync({
      type: 'application/pdf',
      copyToCacheDirectory: true,
    });
    if (!result.canceled && result.assets.length > 0) {
      setSelectedFile(result.assets[0]);
    }
  };

  const handleAnalyze = async () => {
    if (!selectedFile) return;
    setAnalyzing(true);
    setPendingJobId(null);
    setProgressMessage('분석 요청 중...');

    const abort = new AbortController();
    abortRef.current = abort;
    let jobId: string | null = null;
    let completed = false;

    try {
      await analyzeDeed(
        selectedFile.uri,
        selectedFile.name,
        selectedFile.mimeType ?? 'application/pdf',
        (event: SseEvent) => {
          if (!jobId) {
            jobId = event.jobId;
            setPendingJobId(event.jobId);
          }
          setProgressMessage(event.message);

          if (event.status === 'COMPLETED' && jobId) {
            completed = true;
            router.replace(`/result/${jobId}`);
          } else if (event.status === 'FAILED') {
            completed = true;
            Alert.alert('분석 실패', event.message || '분석 중 오류가 발생했습니다.');
            setAnalyzing(false);
          }
        },
        abort.signal,
      );
      // SSE 스트림이 COMPLETED/FAILED 없이 종료된 경우
      if (!completed) {
        setAnalyzing(false);
        setProgressMessage('연결이 끊어졌습니다. 결과를 확인해보세요.');
      }
    } catch (error) {
      if ((error as Error).name !== 'AbortError') {
        Alert.alert('오류', error instanceof Error ? error.message : '분석 요청에 실패했습니다.');
        setAnalyzing(false);
      }
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backText}>← 뒤로</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>등기부등본 분석</Text>
        <View style={styles.backButton} />
      </View>

      <View style={styles.content}>
        <TouchableOpacity
          style={[styles.pickArea, selectedFile && styles.pickAreaSelected]}
          onPress={handlePickDocument}
          disabled={analyzing}
        >
          {selectedFile ? (
            <>
              <Text style={styles.fileIcon}>📄</Text>
              <Text style={styles.fileName} numberOfLines={2}>{selectedFile.name}</Text>
              {!analyzing && <Text style={styles.fileHint}>탭하여 다시 선택</Text>}
            </>
          ) : (
            <>
              <Text style={styles.fileIcon}>📁</Text>
              <Text style={styles.pickTitle}>PDF 파일 선택</Text>
              <Text style={styles.pickHint}>등기부등본 PDF를 선택하세요</Text>
            </>
          )}
        </TouchableOpacity>
      </View>

      <View style={styles.footer}>
        {progressMessage ? (
          <Text style={[styles.progressMessage, !analyzing && styles.progressMessageMuted]}>
            {progressMessage}
          </Text>
        ) : null}
        {!analyzing && pendingJobId ? (
          <TouchableOpacity
            style={styles.resultButton}
            onPress={() => router.replace(`/result/${pendingJobId}`)}
          >
            <Text style={styles.resultButtonText}>결과 확인하기</Text>
          </TouchableOpacity>
        ) : null}
        <TouchableOpacity
          style={[styles.analyzeButton, !selectedFile && styles.analyzeButtonDisabled]}
          onPress={handleAnalyze}
          disabled={!selectedFile || analyzing}
        >
          {analyzing ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.analyzeText}>분석 시작</Text>
          )}
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
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
  backButton: {
    width: 60,
  },
  backText: {
    fontSize: 16,
    color: '#2563EB',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#0F172A',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    padding: 24,
  },
  pickArea: {
    borderWidth: 2,
    borderColor: '#CBD5E1',
    borderStyle: 'dashed',
    borderRadius: 16,
    paddingVertical: 48,
    paddingHorizontal: 24,
    alignItems: 'center',
    backgroundColor: '#fff',
    gap: 12,
  },
  pickAreaSelected: {
    borderColor: '#2563EB',
    borderStyle: 'solid',
    backgroundColor: '#EFF6FF',
  },
  fileIcon: {
    fontSize: 52,
  },
  pickTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#0F172A',
  },
  pickHint: {
    fontSize: 14,
    color: '#64748B',
    textAlign: 'center',
  },
  fileName: {
    fontSize: 15,
    fontWeight: '600',
    color: '#1E40AF',
    textAlign: 'center',
  },
  fileHint: {
    fontSize: 13,
    color: '#64748B',
  },
  footer: {
    padding: 24,
    paddingBottom: 48,
    gap: 12,
  },
  progressMessage: {
    fontSize: 14,
    color: '#2563EB',
    textAlign: 'center',
    fontWeight: '500',
  },
  progressMessageMuted: {
    color: '#64748B',
  },
  resultButton: {
    backgroundColor: '#F0FDF4',
    borderWidth: 1.5,
    borderColor: '#86EFAC',
    height: 52,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  resultButtonText: {
    color: '#15803D',
    fontSize: 16,
    fontWeight: '700',
  },
  analyzeButton: {
    backgroundColor: '#2563EB',
    height: 56,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#2563EB',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 4,
  },
  analyzeButtonDisabled: {
    backgroundColor: '#CBD5E1',
    shadowOpacity: 0,
    elevation: 0,
  },
  analyzeText: {
    color: '#fff',
    fontSize: 17,
    fontWeight: '700',
  },
});
