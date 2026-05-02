import * as Sentry from '@sentry/react-native';
import { Platform } from 'react-native';

type LogContext = Record<string, unknown>;

const isDev = (process.env.EXPO_PUBLIC_ENV ?? 'dev') !== 'prod';

function baseContext(): LogContext {
  return {
    platform: Platform.OS,
    env: process.env.EXPO_PUBLIC_ENV ?? 'dev',
  };
}

export const logger = {
  info(tag: string, message: string, context?: LogContext): void {
    if (!isDev) return;
    console.log(`[INFO] [${tag}] ${message}`, { ...baseContext(), ...context });
  },

  warn(tag: string, message: string, context?: LogContext): void {
    const merged = { ...baseContext(), ...context };
    console.warn(`[WARN] [${tag}] ${message}`, merged);
    Sentry.addBreadcrumb({ level: 'warning', category: tag, message, data: merged });
  },

  error(tag: string, message: string, error?: unknown, context?: LogContext): void {
    const merged = { ...baseContext(), ...context };
    console.error(`[ERROR] [${tag}] ${message}`, merged, error ?? '');
    Sentry.withScope((scope) => {
      scope.setTag('tag', tag);
      scope.setExtras(merged);
      if (error instanceof Error) {
        Sentry.captureException(error);
      } else {
        Sentry.captureMessage(`[${tag}] ${message}`, 'error');
      }
    });
  },
};
