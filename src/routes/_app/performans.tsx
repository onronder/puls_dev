import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

import { DataList } from '#/components/puls/DataList'
import { EmptyState } from '#/components/puls/EmptyState'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Skeleton } from '#/components/ui/skeleton'
import { fetchCompetencyTemplates } from '#/lib/queries/performans'

export const Route = createFileRoute('/_app/performans')({
  component: PerformansPage,
})

function PerformansPage() {
  const { t } = useTranslation()
  const { data: templates, isLoading } = useQuery({
    queryKey: ['performans-competencies'],
    queryFn: fetchCompetencyTemplates,
  })

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <PageHeader
        title={t('performans.title')}
        subtitle={t('performans.subtitle')}
        badge={<StatusPill tone="info">{t('performans.phaseBadge')}</StatusPill>}
        actions={
          <Button type="button" variant="outline" disabled>
            {t('performans.actions.createCycle')}
          </Button>
        }
      />

      <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
        <MetricCard compact label={t('performans.metrics.activeCycle')} value="2026 H1" />
        <MetricCard compact label={t('performans.metrics.avgScore')} value="82,4" />
        <MetricCard compact label={t('performans.metrics.templates')} value={String(templates?.length ?? 0)} />
        <MetricCard compact label={t('performans.metrics.pendingReviews')} value="—" hint={t('common.soon')} />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <section>
          <SectionHeader
            title={t('performans.sections.competencies')}
            description={t('performans.sections.competenciesHint')}
          />
          {isLoading ? (
            <div className="space-y-2">
              <Skeleton className="h-14 w-full rounded-xl" />
              <Skeleton className="h-14 w-full rounded-xl" />
            </div>
          ) : templates && templates.length > 0 ? (
            <DataList
              items={templates.map((item) => ({
                id: item.id,
                title: item.name,
                subtitle: item.description ?? undefined,
                meta: item.weight ? `${item.weight}%` : undefined,
              }))}
            />
          ) : (
            <EmptyState title={t('performans.empty.competencies')} />
          )}
        </section>

        <section>
          <SectionHeader
            title={t('performans.sections.cycles')}
            description={t('performans.sections.cyclesHint')}
          />
          <EmptyState
            title={t('performans.empty.cycles')}
            description={t('performans.empty.cyclesHint')}
            action={
              <Button type="button" variant="outline" disabled>
                {t('performans.actions.createCycle')}
              </Button>
            }
          />
        </section>
      </div>

      <section className="mt-6">
        <SectionHeader
          title={t('performans.sections.goals')}
          description={t('performans.sections.goalsHint')}
        />
        <EmptyState title={t('performans.empty.goals')} />
      </section>
    </div>
  )
}
