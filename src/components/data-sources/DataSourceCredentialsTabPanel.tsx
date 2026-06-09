import { Check, KeyRound, ShieldCheck } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { TabsContent } from '#/components/ui/tabs'

import { formatDateTime, readinessTone } from './dataSourceUi'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'

type DataSourceCredentialsTabPanelProps = DataSourceTechnicalTabPanelProps & {
  credentialSheetOpen: boolean
  setCredentialSheetOpen: (open: boolean) => void
}

export function DataSourceCredentialsTabPanel({
  data,
  permissions,
  mutations,
  credentialSheetOpen,
  setCredentialSheetOpen,
}: DataSourceCredentialsTabPanelProps) {
  const { t, i18n } = useTranslation()
  return (
    <TabsContent value="credentials" className="mt-6">
      <section id="erp-credential-boundary" className="scroll-mt-6">
        <SectionHeader
          title={t('erp.sections.credentialBoundary')}
          description={t('erp.sections.credentialBoundaryDescription')}
        />
        <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
          <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
            <div className="flex items-start gap-3">
              <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-[var(--color-bg-elevated)] text-[var(--color-primary)]">
                <KeyRound className="h-5 w-5" aria-hidden />
              </span>
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                    {t(data.credentialBoundary.statusLabelKey)}
                  </h2>
                  <StatusPill tone={readinessTone(data.credentialBoundary.status)}>
                    {t(`erp.readinessStatus.${data.credentialBoundary.status}`)}
                  </StatusPill>
                </div>
                <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                  {t(data.credentialBoundary.descriptionKey)}
                </p>
                <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                  {t('erp.credentialBoundary.noReadback')}
                </p>
              </div>
            </div>

            <div className="grid gap-2 text-sm md:min-w-[260px]">
              <div className="flex items-center justify-between gap-3 rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                <span className="text-[var(--color-text-muted)]">
                  {t('erp.credentialBoundary.authMode')}
                </span>
                <span className="text-right font-medium text-[var(--color-text-primary)]">
                  {t(`erp.authModes.${data.credentialBoundary.authMode}`)}
                </span>
              </div>
              <div className="flex items-center justify-between gap-3 rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                <span className="text-[var(--color-text-muted)]">
                  {t('erp.credentialBoundary.required')}
                </span>
                <span className="text-right font-medium text-[var(--color-text-primary)]">
                  {t(
                    data.credentialBoundary.required
                      ? 'erp.credentialBoundary.requiredValues.yes'
                      : 'erp.credentialBoundary.requiredValues.no',
                  )}
                </span>
              </div>
              <div className="flex items-center justify-between gap-3 rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                <span className="text-[var(--color-text-muted)]">
                  {t('erp.credentialBoundary.lastVerified')}
                </span>
                <span className="text-right font-medium text-[var(--color-text-primary)]">
                  {formatDateTime(
                    data.credentialBoundary.lastVerifiedAt,
                    i18n.language,
                    t('erp.credentialBoundary.notRecorded'),
                  )}
                </span>
              </div>
            </div>
          </div>
          <div className="mt-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-3">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                    {t(data.credentialHandoff.statusLabelKey)}
                  </p>
                  <StatusPill tone={readinessTone(data.credentialHandoff.readiness)}>
                    {t(`erp.readinessStatus.${data.credentialHandoff.readiness}`)}
                  </StatusPill>
                </div>
                <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                  {t(data.credentialHandoff.descriptionKey)}
                </p>
                <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                  {t(data.credentialHandoff.actionDescriptionKey)}
                </p>
                {data.credentialHandoff.requestedAt ? (
                  <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                    {t('erp.credentialHandoff.requestedAt', {
                      value: formatDateTime(
                        data.credentialHandoff.requestedAt,
                        i18n.language,
                        t('erp.credentialBoundary.notRecorded'),
                      ),
                    })}
                  </p>
                ) : null}
              </div>
              <Button
                type="button"
                variant="outline"
                className="touch-target w-full sm:w-auto"
                disabled={
                  !data.credentialHandoff.requestable ||
                  !permissions.canManageConnectors ||
                  mutations.requestCredentialHandoff.isPending
                }
                onClick={() => setCredentialSheetOpen(true)}
              >
                <ShieldCheck className="h-4 w-4" />
                {permissions.canRequestCredentialHandoff
                  ? t('erp.credentialHandoff.openSheet')
                  : !permissions.canManageConnectors && data.credentialHandoff.requestable
                    ? t('erp.credentialHandoff.adminRequired')
                    : t(data.credentialHandoff.actionLabelKey)}
              </Button>
            </div>
          </div>
        </div>
        <SheetShell
          open={credentialSheetOpen}
          onOpenChange={setCredentialSheetOpen}
          title={t('erp.credentialHandoff.sheet.title', { source: data.provider.label })}
          description={t('erp.credentialHandoff.sheet.description')}
          footer={
            <div className="flex w-full flex-col gap-2 sm:flex-row sm:justify-end">
              <Button
                type="button"
                variant="outline"
                className="touch-target w-full sm:w-auto"
                onClick={() => setCredentialSheetOpen(false)}
              >
                {t('erp.credentialHandoff.sheet.close')}
              </Button>
              <Button
                type="button"
                className="touch-target w-full sm:w-auto"
                disabled={
                  !permissions.canRequestCredentialHandoff ||
                  mutations.requestCredentialHandoff.isPending
                }
                onClick={() => void mutations.requestCredentialHandoff.mutateAsync()}
              >
                {mutations.requestCredentialHandoff.isPending
                  ? t('erp.credentialHandoff.sheet.requesting')
                  : t('erp.credentialHandoff.sheet.request')}
              </Button>
            </div>
          }
        >
          <div className="space-y-4">
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
              <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                {t('erp.credentialHandoff.sheet.authMode')}
              </p>
              <p className="mt-2 text-lg font-semibold text-[var(--color-text-primary)]">
                {t(`erp.authModes.${data.credentialBoundary.authMode}`)}
              </p>
              <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                {t('erp.credentialHandoff.sheet.authModeDescription')}
              </p>
            </div>
            <ul className="divide-y divide-[var(--color-border)] rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
              {['writeOnly', 'opaqueReference', 'noReadback', 'runtimeVerification'].map((item) => (
                <li key={item} className="flex items-start gap-3 p-3">
                  <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                    <Check className="h-3.5 w-3.5" aria-hidden />
                  </span>
                  <div>
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {t(`erp.credentialHandoff.sheet.steps.${item}.label`)}
                    </p>
                    <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                      {t(`erp.credentialHandoff.sheet.steps.${item}.description`)}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
            <div className="rounded-xl border border-[color-mix(in_srgb,var(--color-warning)_25%,transparent)] bg-[var(--color-warning-soft)] p-4">
              <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                {t('erp.credentialHandoff.sheet.guardrailTitle')}
              </p>
              <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-secondary)]">
                {t('erp.credentialHandoff.sheet.guardrailBody')}
              </p>
            </div>
          </div>
        </SheetShell>
      </section>
    </TabsContent>
  )
}
