import { useTranslation } from 'react-i18next'

import { StatusPill } from '#/components/puls/StatusPill'
import { cn } from '#/lib/utils'

type DemoSourcePillProps = {
  visible?: boolean
  className?: string
}

export function DemoSourcePill({ visible = true, className }: DemoSourcePillProps) {
  const { t } = useTranslation()

  if (!visible) return null

  return (
    <div className={cn('mb-4 flex flex-wrap gap-2', className)}>
      <StatusPill tone="neutral">{t('orgSetupReadiness.source.demo')}</StatusPill>
    </div>
  )
}
