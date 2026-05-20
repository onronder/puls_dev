import { Link, createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Badge } from '#/components/ui/badge'
import { Button } from '#/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '#/components/ui/card'
import { Input } from '#/components/ui/input'
import { Label } from '#/components/ui/label'
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
    <div className="mx-auto max-w-5xl p-4 md:p-8">
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold md:text-3xl">{t('performans.title')}</h1>
          <p className="mt-2 text-[var(--color-text-muted)]">{t('performans.subtitle')}</p>
        </div>
        <Badge variant="secondary">{t('performans.sprintBadge')}</Badge>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">{t('performans.sections.competencies')}</CardTitle>
            <CardDescription>{t('performans.sections.competenciesHint')}</CardDescription>
          </CardHeader>
          <CardContent>
            {templatesLoading ? (
              <div className="space-y-2">
                <Skeleton className="h-10 w-full" />
                <Skeleton className="h-10 w-full" />
              </div>
            ) : templates && templates.length > 0 ? (
              <ul className="space-y-2">
                {templates.map((item) => (
                  <li
                    key={item.id}
                    className="rounded-lg border border-[var(--color-border)] px-3 py-2"
                  >
                    <p className="font-medium">{item.name}</p>
                    {item.description ? (
                      <p className="text-xs text-[var(--color-text-muted)]">{item.description}</p>
                    ) : null}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-sm text-[var(--color-text-muted)]">
                {t('performans.empty.competencies')}
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">{t('performans.sections.cycles')}</CardTitle>
            <CardDescription>{t('performans.sections.cyclesHint')}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {cyclesLoading ? (
              <Skeleton className="h-20 w-full" />
            ) : cycles && cycles.length > 0 ? (
              <ul className="space-y-2">
                {cycles.map((cycle) => (
                  <li
                    key={cycle.id}
                    className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-[var(--color-border)] px-3 py-2"
                  >
                    <div>
                      <p className="font-medium">{cycle.name}</p>
                      <p className="text-xs text-[var(--color-text-muted)]">
                        {cycle.starts_at} → {cycle.ends_at}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <Badge variant={cycle.status === 'active' ? 'default' : 'outline'}>
                        {t(`performans.cycleStatus.${cycle.status}`)}
                      </Badge>
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
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-sm text-[var(--color-text-muted)]">{t('performans.empty.cycles')}</p>
            )}

            {isManagerView ? (
              <>
                <Separator />
                <form
                  className="space-y-3"
                  onSubmit={(e) => {
                    e.preventDefault()
                    void createMutation.mutateAsync()
                  }}
                >
                  <div className="space-y-2">
                    <Label htmlFor="cycle-name">{t('performans.form.cycleName')}</Label>
                    <Input
                      id="cycle-name"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      required
                    />
                  </div>
                  <div className="grid gap-3 sm:grid-cols-2">
                    <div className="space-y-2">
                      <Label htmlFor="starts-at">{t('performans.form.startsAt')}</Label>
                      <Input
                        id="starts-at"
                        type="date"
                        value={startsAt}
                        onChange={(e) => setStartsAt(e.target.value)}
                        required
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="ends-at">{t('performans.form.endsAt')}</Label>
                      <Input
                        id="ends-at"
                        type="date"
                        value={endsAt}
                        onChange={(e) => setEndsAt(e.target.value)}
                        required
                      />
                    </div>
                  </div>
                  {formError ? (
                    <p className="text-sm text-[var(--color-danger)]">{formError}</p>
                  ) : null}
                  <Button type="submit" disabled={createMutation.isPending}>
                    {createMutation.isPending
                      ? t('performans.actions.saving')
                      : t('performans.actions.createCycle')}
                  </Button>
                </form>
              </>
            ) : (
              <p className="text-xs text-[var(--color-text-muted)]">
                {t('performans.managerOnlyCreate')}
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      <Card className="mt-4">
        <CardHeader>
          <CardTitle className="text-base">{t('performans.sections.goals')}</CardTitle>
          <CardDescription>{t('performans.sections.goalsHint')}</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm text-[var(--color-text-muted)]">{t('performans.empty.goals')}</p>
          <Button variant="ghost" asChild>
            <Link to="/dashboard">{t('performans.actions.backDashboard')}</Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}
