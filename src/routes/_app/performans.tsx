import { Link, createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { DataList } from '#/components/puls/DataList'
import { EmptyState } from '#/components/puls/EmptyState'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Separator } from '#/components/ui/separator'
import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import {
  createPerformansCycle,
  fetchCompetencyTemplates,
  fetchPerformansCycles,
  updateCycleStatus,
  type PerformansCycle,
} from '#/lib/queries/performans'

export const Route = createFileRoute('/_app/performans')({
  component: PerformansPage,
})

function PerformansPage() {
  const { t } = useTranslation()
  const { user, activePersona } = useAuth()
  const queryClient = useQueryClient()
  const isManagerView = activePersona === 'manager'

  const { data: templates, isLoading: templatesLoading } = useQuery({
    queryKey: ['performans-competencies'],
    queryFn: fetchCompetencyTemplates,
  })

  const { data: cycles, isLoading: cyclesLoading } = useQuery({
    queryKey: ['performans-cycles'],
    queryFn: fetchPerformansCycles,
  })

  const [name, setName] = useState('')
  const [startsAt, setStartsAt] = useState('')
  const [endsAt, setEndsAt] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  const activeCycle = useMemo(
    () => cycles?.find((cycle) => cycle.status === 'active') ?? null,
    [cycles],
  )

  const createMutation = useMutation({
    mutationFn: () => createPerformansCycle(user!.id, { name, starts_at: startsAt, ends_at: endsAt }),
    onSuccess: (result) => {
      if (result.error) {
        setFormError(result.error === 'no_tenant' ? t('performans.errors.noTenant') : result.error)
        return
      }
      setFormError(null)
      setName('')
      setStartsAt('')
      setEndsAt('')
      void queryClient.invalidateQueries({ queryKey: ['performans-cycles'] })
    },
  })

  const statusMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: PerformansCycle['status'] }) =>
      updateCycleStatus(id, status),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['performans-cycles'] })
    },
  })

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <PageHeader
        title={t('performans.title')}
        subtitle={t('performans.subtitle')}
        badge={<StatusPill tone="info">{t('performans.phaseBadge')}</StatusPill>}
      />

      <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
        <MetricCard
          compact
          label={t('performans.metrics.activeCycle')}
          value={activeCycle?.name ?? '—'}
        />
        <MetricCard compact label={t('performans.metrics.avgScore')} value="82,4" />
        <MetricCard
          compact
          label={t('performans.metrics.templates')}
          value={String(templates?.length ?? 0)}
        />
        <MetricCard
          compact
          label={t('performans.metrics.pendingReviews')}
          value="—"
          hint={t('common.soon')}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <section>
          <SectionHeader
            title={t('performans.sections.competencies')}
            description={t('performans.sections.competenciesHint')}
          />
          {templatesLoading ? (
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
          {cyclesLoading ? (
            <Skeleton className="h-24 w-full rounded-xl" />
          ) : cycles && cycles.length > 0 ? (
            <DataList
              items={cycles.map((cycle) => ({
                id: cycle.id,
                title: cycle.name,
                subtitle: `${cycle.starts_at} → ${cycle.ends_at}`,
                trailing: (
                  <div className="flex items-center gap-2">
                    <StatusPill tone={cycle.status === 'active' ? 'success' : 'neutral'}>
                      {t(`performans.cycleStatus.${cycle.status}`)}
                    </StatusPill>
                    {isManagerView && cycle.status === 'draft' ? (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() =>
                          void statusMutation.mutateAsync({ id: cycle.id, status: 'active' })
                        }
                      >
                        {t('performans.actions.activate')}
                      </Button>
                    ) : null}
                  </div>
                ),
              }))}
            />
          ) : (
            <EmptyState
              title={t('performans.empty.cycles')}
              description={t('performans.empty.cyclesHint')}
            />
          )}

          {isManagerView ? (
            <form
              className="mt-4 space-y-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
              onSubmit={(event) => {
                event.preventDefault()
                void createMutation.mutateAsync()
              }}
            >
              <FormField label={t('performans.form.cycleName')} htmlFor="cycle-name" required>
                <Input
                  id="cycle-name"
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  required
                />
              </FormField>
              <div className="grid gap-3 sm:grid-cols-2">
                <FormField label={t('performans.form.startsAt')} htmlFor="starts-at" required>
                  <Input
                    id="starts-at"
                    type="date"
                    value={startsAt}
                    onChange={(event) => setStartsAt(event.target.value)}
                    required
                  />
                </FormField>
                <FormField label={t('performans.form.endsAt')} htmlFor="ends-at" required>
                  <Input
                    id="ends-at"
                    type="date"
                    value={endsAt}
                    onChange={(event) => setEndsAt(event.target.value)}
                    required
                  />
                </FormField>
              </div>
              {formError ? <p className="text-sm text-[var(--color-danger)]">{formError}</p> : null}
              <Button type="submit" disabled={createMutation.isPending} className="w-full sm:w-auto">
                {createMutation.isPending
                  ? t('performans.actions.saving')
                  : t('performans.actions.createCycle')}
              </Button>
            </form>
          ) : (
            <p className="mt-3 text-xs text-[var(--color-text-muted)]">
              {t('performans.managerOnlyCreate')}
            </p>
          )}
        </section>
      </div>

      <section className="mt-6">
        <Separator className="mb-6" />
        <SectionHeader
          title={t('performans.sections.goals')}
          description={t('performans.sections.goalsHint')}
          action={
            <Button variant="ghost" asChild>
              <Link to="/dashboard">{t('performans.actions.backDashboard')}</Link>
            </Button>
          }
        />
        <EmptyState title={t('performans.empty.goals')} />
      </section>
    </div>
  )
}
