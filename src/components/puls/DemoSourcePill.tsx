import { AlertTriangle } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { StatusPill } from '#/components/puls/StatusPill'
import { cn } from '#/lib/utils'

type DemoSourcePillProps = {
  visible?: boolean
  fallbackReason?: 'empty' | 'error'
  className?: string
}

export function DemoSourcePill({
  visible = true,
  fallbackReason,
  className,
}: DemoSourcePillProps) {
  const { t } = useTranslation()

  if (!visible) return null

  if (fallbackReason === 'error') {
    return (
      <div
        role="alert"
        className={cn(
          'mb-4 flex items-start gap-3 rounded-xl border border-[color-mix(in_srgb,var(--color-danger)_35%,transparent)] bg-[var(--color-danger-soft)] p-3 text-sm text-[var(--color-danger)]',
          className,
        )}
      >
        <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden />
        <div className="min-w-0">
          <p className="font-semibold">{t('demoSource.errorTitle')}</p>
          <p className="mt-1 text-[var(--color-text-secondary)]">{t('demoSource.errorBody')}</p>
        </div>
      </div>
    )
  }

  return (
    <div className={cn('mb-4 flex flex-wrap gap-2', className)}>
      <StatusPill tone="neutral">{t('orgSetupReadiness.source.demo')}</StatusPill>
    </div>
  )
}
