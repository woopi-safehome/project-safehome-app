import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';
import { router } from 'expo-router';

export default function HomeScreen() {
  return (
    <View style={styles.container}>
      <View style={styles.hero}>
        <Text style={styles.emoji}>🏠</Text>
        <Text style={styles.title}>SafeHome</Text>
        <Text style={styles.subtitle}>전세사기 예방 등기부등본 분석</Text>
      </View>

      <View style={styles.infoBox}>
        <InfoItem emoji="📄" text="등기부등본 PDF 업로드" />
        <InfoItem emoji="🤖" text="AI가 권리 관계 자동 분석" />
        <InfoItem emoji="🔍" text="위험 신호 및 안전 등급 확인" />
      </View>

      <View style={styles.footer}>
        <TouchableOpacity style={styles.ctaButton} onPress={() => router.push('/upload')}>
          <Text style={styles.ctaText}>등기부등본 분석하기</Text>
        </TouchableOpacity>
        <Text style={styles.disclaimer}>
          분석 결과는 참고용이며 법적 효력이 없습니다.{'\n'}
          중요한 계약 전 전문가 상담을 권장합니다.
        </Text>
      </View>
    </View>
  );
}

function InfoItem({ emoji, text }: { emoji: string; text: string }) {
  return (
    <View style={styles.infoItem}>
      <Text style={styles.infoEmoji}>{emoji}</Text>
      <Text style={styles.infoText}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8FAFC',
    paddingHorizontal: 24,
    justifyContent: 'space-between',
    paddingTop: 80,
    paddingBottom: 40,
  },
  hero: {
    alignItems: 'center',
    gap: 8,
  },
  emoji: {
    fontSize: 64,
    marginBottom: 8,
  },
  title: {
    fontSize: 36,
    fontWeight: '800',
    color: '#0F172A',
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 16,
    color: '#64748B',
    textAlign: 'center',
  },
  infoBox: {
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 24,
    gap: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  infoItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  infoEmoji: {
    fontSize: 28,
    width: 40,
    textAlign: 'center',
  },
  infoText: {
    fontSize: 16,
    color: '#1E293B',
    fontWeight: '500',
  },
  footer: {
    gap: 16,
  },
  ctaButton: {
    backgroundColor: '#2563EB',
    height: 58,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#2563EB',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 4,
  },
  ctaText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
  },
  disclaimer: {
    fontSize: 12,
    color: '#94A3B8',
    textAlign: 'center',
    lineHeight: 18,
  },
});
