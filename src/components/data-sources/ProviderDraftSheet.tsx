import { useTranslation } from 'react-i18next'

import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'

type ProviderReadinessStatus = 'ready' | 'partial' | 'blocked'

type ProviderRequirement = {
  id: string
  labelKey: string
  descriptionKey: string
  status: ProviderReadinessStatus
}

export type ProviderDraftSheetOption = {
  id: string
  labelKey: string
  readinessLabelKey: string
  setupAvailable: boolean
  categoryKey: string
  availabilityKey: string
  status: ProviderReadinessStatus
  requirements: ProviderRequirement[]
}

type ProviderDraftSheetProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  onClose: () => void
  provider: ProviderDraftSheetOption
  canManage: boolean
  canStart: boolean
  isPending: boolean
  onStart: () => void
}

function readinessTone(status: ProviderReadinessStatus): StatusTone {
  if (status === 'ready') return 'success'
  if (status === 'partial') return 'warning'
  return 'neutral'
}

export function ProviderDraftSheet({
  open,
  onOpenChange,
  onClose,
  provider,
  canManage,
  canStart,
  isPending,
  onStart,
}: ProviderDraftSheetProps) {
  const { t } = useTranslation()

  return (
    <SheetShell
      open={open}
      onOpenChange={onOpenChange}
      title={t('erp.draftSheet.title', { provider: t(provider.labelKey) })}
      description={t('erp.draftSheet.description')}
      footer={
        <div className="flex w-full flex-col gap-2 sm:flex-row sm:justify-end">
          <Button
            type="button"
            variant="outline"
            className="touch-target w-full sm:w-auto"
            onClick={onClose}
          >
            {t('erp.draftSheet.close')}
          </Button>
          <Button
            type="button"
            className="touch-target w-full sm:w-auto"
            disabled={!canManage || !canStart || isPending}
            aria-disabled={!canManage || !canStart || isPending}
            onClick={onStart}
          >
            {isPending
              ? t('erp.draftSheet.creating')
              : !canManage
                ? t('erp.draftSheet.adminRequiredAction')
                : canStart
                  ? t('erp.draftSheet.startSetup')
                  : t('erp.draftSheet.futureProvider')}
          </Button>
        </div>
      }
    >
      <div className="space-y-5">
        <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                {t('erp.draftSheet.summary')}
              </p>
              <h3 className="mt-2 text-lg font-semibold text-[var(--color-text-primary)]">
                {t(provider.labelKey)}
              </h3>
              <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-muted)]">
                {t(provider.readinessLabelKey)}
              </p>
              <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                {provider.setupAvailable
                  ? t('erp.draftSheet.persistedSetupHint')
                  : t('erp.draftSheet.futureProviderHint')}
              </p>
              <dl className="mt-4 grid gap-3 text-xs sm:grid-cols-2">
                <div>
                  <dt className="font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.providerCatalog.labels.category')}
                  </dt>
                  <dd className="mt-1 text-[var(--color-text-primary)]">
                    {t(provider.categoryKey)}
                  </dd>
                </div>
                <div>
                  <dt className="font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.providerCatalog.labels.availability')}
                  </dt>
                  <dd className="mt-1 text-[var(--color-text-primary)]">
                    {t(provider.availabilityKey)}
                  </dd>
                </div>
              </dl>
            </div>
            <StatusPill tone={readinessTone(provider.status)}>
              {t(`erp.readinessStatus.${provider.status}`)}
            </StatusPill>
          </div>
        </div>

        <div>
          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
            {t('erp.draftSheet.requirements')}
          </p>
          <ul className="mt-2 divide-y divide-[var(--color-border)] rounded-xl border border-[var(--color-border)]">
            {provider.requirements.map((requirement) => (
              <li key={requirement.id} className="p-3">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-[var(--color-text-primary)]">
                      {t(requirement.labelKey)}
                    </p>
                    <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                      {t(requirement.descriptionKey)}
                    </p>
                  </div>
                  <StatusPill tone={readinessTone(requirement.status)}>
                    {t(`erp.readinessStatus.${requirement.status}`)}
                  </StatusPill>
                </div>
              </li>
            ))}
          </ul>
        </div>

        <div className="rounded-xl border border-[color-mix(in_srgb,var(--color-warning)_25%,transparent)] bg-[var(--color-warning-soft)] p-4">
          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
            {t('erp.draftSheet.guardrailTitle')}
          </p>
          <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-secondary)]">
            {t('erp.draftSheet.guardrailBody')}
          </p>
        </div>
      </div>
    </SheetShell>
  )
}
