import { useRef, useState } from 'react';
import { ActivityIndicator, Alert, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { router } from 'expo-router';
import * as DocumentPicker from 'expo-document-picker';
import { uploadDeed } from '@/services/api';
import { logger } from '@/services/logger';
import type { LeaseType } from '@/types/deed';

const LEASE_TYPES: { value: LeaseType; label: string }[] = [
  { value: '전세', label: '전세' },
  { value: '월세', label: '월세' },
];

export default function UploadScreen() {
  const [selectedFile, setSelectedFile] = useState<DocumentPicker.DocumentPickerAsset | null>(null);
  const [leaseType, setLeaseType] = useState<LeaseType | null>(null);
  const [uploading, setUploading] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

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
    setUploading(true);

    const abort = new AbortController();
    abortRef.current = abort;

    try {
      const jobId = await uploadDeed(
        selectedFile.uri,
        selectedFile.name,
        selectedFile.mimeType ?? 'application/pdf',
        abort.signal,
        leaseType ?? undefined,
      );
      router.replace(`/analyzing/${jobId}`);
    } catch (error) {
      if ((error as Error).name !== 'AbortError') {
        logger.error('Upload', '업로드 실패', error, {
          fileName: selectedFile.name,
          leaseType: leaseType ?? 'none',
        });
        Alert.alert('오류', error instanceof Error ? error.message : '분석 요청에 실패했습니다.');
        setUploading(false);
      }
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton} disabled={uploading}>
          <Text style={[styles.backText, uploading && styles.backTextDisabled]}>← 뒤로</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>등기부등본 분석</Text>
        <View style={styles.backButton} />
      </View>

      <View style={styles.content}>
        <TouchableOpacity
          style={[styles.pickArea, selectedFile && styles.pickAreaSelected]}
          onPress={handlePickDocument}
          disabled={uploading}
        >
          {selectedFile ? (
            <>
              <Text style={styles.fileIcon}>📄</Text>
              <Text style={styles.fileName} numberOfLines={2}>{selectedFile.name}</Text>
              {!uploading && <Text style={styles.fileHint}>탭하여 다시 선택</Text>}
            </>
          ) : (
            <>
              <Text style={styles.fileIcon}>📁</Text>
              <Text style={styles.pickTitle}>PDF 파일 선택</Text>
              <Text style={styles.pickHint}>등기부등본 PDF를 선택하세요</Text>
            </>
          )}
        </TouchableOpacity>

        {/* 임대차 유형 선택 */}
        <View style={styles.leaseSection}>
          <Text style={styles.leaseLabel}>임대차 유형 <Text style={styles.leaseLabelOptional}>(선택)</Text></Text>
          <View style={styles.leaseRow}>
            {LEASE_TYPES.map(({ value, label }) => (
              <TouchableOpacity
                key={value}
                style={[styles.leaseChip, leaseType === value && styles.leaseChipActive]}
                onPress={() => setLeaseType(prev => prev === value ? null : value)}
                disabled={uploading}
              >
                <Text style={[styles.leaseChipText, leaseType === value && styles.leaseChipTextActive]}>
                  {label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
          {leaseType && (
            <Text style={styles.leaseHint}>
              {leaseType === '전세' ? '전세 보증금 보호 관점으로 분석합니다' : '월세 계약 안전성 관점으로 분석합니다'}
            </Text>
          )}
        </View>
      </View>

      <View style={styles.footer}>
        <TouchableOpacity
          style={[styles.analyzeButton, !selectedFile && styles.analyzeButtonDisabled]}
          onPress={handleAnalyze}
          disabled={!selectedFile || uploading}
        >
          {uploading ? (
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
  backTextDisabled: {
    color: '#CBD5E1',
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
  leaseSection: {
    marginTop: 24,
    gap: 10,
  },
  leaseLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#0F172A',
  },
  leaseLabelOptional: {
    fontSize: 12,
    fontWeight: '400',
    color: '#94A3B8',
  },
  leaseRow: {
    flexDirection: 'row',
    gap: 10,
  },
  leaseChip: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 10,
    borderWidth: 1.5,
    borderColor: '#CBD5E1',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  leaseChipActive: {
    borderColor: '#2563EB',
    backgroundColor: '#EFF6FF',
  },
  leaseChipText: {
    fontSize: 15,
    fontWeight: '600',
    color: '#64748B',
  },
  leaseChipTextActive: {
    color: '#2563EB',
  },
  leaseHint: {
    fontSize: 12,
    color: '#2563EB',
    textAlign: 'center',
  },
  footer: {
    padding: 24,
    paddingBottom: 48,
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
