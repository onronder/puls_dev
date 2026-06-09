import { ShieldCheck } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { TabsContent } from '#/components/ui/tabs'

import { domainOwnershipTone, readinessTone } from './dataSourceUi'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'

export function DataSourceFieldsTabPanel({ data }: Pick<DataSourceTechnicalTabPanelProps, 'data'>) {
  const { t } = useTranslation()
  return (
    <TabsContent value="fields" className="mt-6">
      <section>
        <SectionHeader
          title={t('erp.sections.namespaces')}
          description={t('erp.sections.namespacesDescription')}
        />
        <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          {data.namespaces.length > 0 ? (
            data.namespaces.map((namespace) => (
              <li key={namespace.id} className="flex items-center justify-between gap-3 p-4">
                <div className="min-w-0">
                  <p className="font-mono text-sm font-semibold text-[var(--color-text-primary)]">
                    {namespace.code}
                  </p>
                  <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                    {namespace.name} · {namespace.sourceType}
                  </p>
                </div>
                <StatusPill tone={namespace.identityCount > 0 ? 'success' : 'warning'}>
                  {t('erp.identityCount', { count: namespace.identityCount })}
                </StatusPill>
              </li>
            ))
          ) : (
            <li className="p-4 text-sm text-[var(--color-text-muted)]">
              {t('erp.empty.namespaces')}
            </li>
          )}
        </ul>
      </section>

      <section id="erp-mapping-discovery" className="mt-8 scroll-mt-6">
        <SectionHeader
          title={t('erp.sections.domainOwnership')}
          description={t('erp.sections.domainOwnershipDescription')}
        />
        <ul className="mb-8 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {data.domainOwnership.map((domain) => (
            <li
              key={domain.id}
              className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                    {t(domain.labelKey)}
                  </p>
                  <p className="mt-1 font-mono text-xs text-[var(--color-text-muted)]">
                    {domain.pulsTarget}
                  </p>
                </div>
                <StatusPill tone={domainOwnershipTone(domain.status)}>
                  {t(`erp.domainOwnership.status.${domain.status}`)}
                </StatusPill>
              </div>
              <p className="mt-3 text-xs text-[var(--color-text-secondary)]">
                {domain.ownerProviderLabel
                  ? t('erp.domainOwnership.owner', { source: domain.ownerProviderLabel })
                  : t('erp.domainOwnership.available')}
              </p>
              <p className="mt-2 font-mono text-xs text-[var(--color-text-muted)]">
                {domain.mappedFields} / {domain.totalFields}
              </p>
            </li>
          ))}
        </ul>

        <SectionHeader
          title={t('erp.sections.canonicalClasses')}
          description={t('erp.sections.canonicalClassesDescription')}
        />
        <ul className="grid gap-3 sm:grid-cols-2">
          {data.canonicalClasses.map((canonicalClass) => (
            <li
              key={canonicalClass.id}
              className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                    {t(canonicalClass.labelKey)}
                  </p>
                  <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                    {t(canonicalClass.descriptionKey)}
                  </p>
                </div>
                <StatusPill tone={readinessTone(canonicalClass.status)}>
                  {t(`erp.readinessStatus.${canonicalClass.status}`)}
                </StatusPill>
              </div>
              <p className="mt-3 font-mono text-xs text-[var(--color-text-muted)]">
                {canonicalClass.pulsTarget}
              </p>
              <div className="mt-4 grid grid-cols-2 gap-3 text-xs">
                <div>
                  <p className="font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.canonicalClasses.mappedFields')}
                  </p>
                  <p className="mt-1 font-mono text-base text-[var(--color-text-primary)]">
                    {canonicalClass.mappedFields} / {canonicalClass.totalFields}
                  </p>
                </div>
                <div>
                  <p className="font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.canonicalClasses.requiredFields')}
                  </p>
                  <p className="mt-1 font-mono text-base text-[var(--color-text-primary)]">
                    {canonicalClass.mappedRequiredFields} / {canonicalClass.requiredFields}
                  </p>
                </div>
              </div>
            </li>
          ))}
        </ul>
      </section>

      <section className="mt-8">
        <SectionHeader
          title={t('erp.sections.mapping')}
          description={t('erp.sections.mappingDescription')}
        />
        <div className="overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          <div className="hidden border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)] sm:grid sm:grid-cols-[1.2fr_1fr_120px] sm:gap-3">
            <div>{t('erp.columns.canonicalField')}</div>
            <div>{t('erp.columns.sourceField')}</div>
            <div className="text-right">{t('erp.columns.status')}</div>
          </div>
          <ul className="divide-y divide-[var(--color-border)]">
            {data.mappings.length > 0 ? (
              data.mappings.map((mapping) => (
                <li
                  key={`${mapping.sourceEntity}-${mapping.canonicalField}-${mapping.sourceField}`}
                  className="grid grid-cols-1 gap-2 px-4 py-3 sm:grid-cols-[1.2fr_1fr_120px] sm:items-center sm:gap-3"
                >
                  <div>
                    <p className="font-mono text-sm font-medium">{mapping.canonicalField}</p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {mapping.sourceEntity} ·{' '}
                      {mapping.required ? t('erp.mapping.required') : t('erp.mapping.optional')}
                    </p>
                  </div>
                  <div className="font-mono text-sm text-[var(--color-text-muted)] sm:text-[var(--color-text-secondary)]">
                    {mapping.sourceField}
                  </div>
                  <div className="sm:justify-self-end">
                    <StatusPill tone={mapping.status === 'mapped' ? 'success' : 'warning'}>
                      {t(`erp.status.${mapping.status}`)}
                    </StatusPill>
                  </div>
                </li>
              ))
            ) : (
              <li className="p-4 text-sm text-[var(--color-text-muted)]">
                {t('erp.empty.mappings')}
              </li>
            )}
          </ul>
        </div>
      </section>

      <section className="mt-8 grid gap-4 lg:grid-cols-[1fr_1fr]">
        <div>
          <SectionHeader
            title={t('erp.sections.transferModes')}
            description={t('erp.sections.transferModesDescription')}
          />
          <ul className="space-y-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-3">
            {data.transferModes.map((mode) => (
              <li key={mode.id} className="flex items-center justify-between gap-3 p-2">
                <span className="text-sm text-[var(--color-text-secondary)]">
                  {t(mode.labelKey)}
                </span>
                <StatusPill tone={readinessTone(mode.status)}>
                  {t(`erp.readinessStatus.${mode.status}`)}
                </StatusPill>
              </li>
            ))}
          </ul>
        </div>

        <div>
          <SectionHeader
            title={t('erp.sections.guardrails')}
            description={t('erp.sections.guardrailsDescription')}
          />
          <ul className="space-y-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-3">
            {data.guardrails.map((guardrail) => (
              <li key={guardrail.id} className="flex items-start gap-3 p-2">
                <ShieldCheck
                  className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]"
                  aria-hidden
                />
                <span className="text-sm text-[var(--color-text-secondary)]">
                  {t(guardrail.labelKey)}
                </span>
              </li>
            ))}
          </ul>
        </div>
      </section>
    </TabsContent>
  )
}
