import { Link, createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

import { Badge } from '#/components/ui/badge'
import { Button } from '#/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '#/components/ui/card'
import { Separator } from '#/components/ui/separator'
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
            {isLoading ? (
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
              <p className="text-sm text-[var(--color-text-muted)]">{t('performans.empty.competencies')}</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">{t('performans.sections.cycles')}</CardTitle>
            <CardDescription>{t('performans.sections.cyclesHint')}</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-[var(--color-text-muted)]">{t('performans.empty.cycles')}</p>
            <Separator className="my-4" />
            <Button variant="outline" disabled>
              {t('performans.actions.createCycle')}
            </Button>
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
