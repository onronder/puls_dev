import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { Briefcase, ClipboardList, FileCheck2, Plus, Scale } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { DataList } from '#/components/puls/DataList'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { fetchDemoPositionsOverview } from '#/lib/demo/puls-demo-data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/pozisyonlar')({
  head: () => ({
    meta: [
      { title: i18n.t('positions.meta.title') },
      {
        name: 'description',
        content: i18n.t('positions.meta.description'),
      },
    ],
  }),
  component: PozisyonlarPage,
})

const POSITION_SKELETON_COUNT = 3
const POSITION_TABLE_GRID_COLS = 'grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)_minmax(0,1fr)_88px]'

function PozisyonlarPage() {
  const { t } = useTranslation()
  const [sheetOpen, setSheetOpen] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['demo-positions-overview'],
    queryFn: fetchDemoPositionsOverview,
  })

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('positions.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('positions.title')}
        subtitle={t('positions.description')}
        actions={
          <Button type="button" className="touch-target w-full sm:w-auto" onClick={() => setSheetOpen(true)}>
            <Plus className="h-4 w-4" />
            {t('positions.actions.add')}
          </Button>
        }
      />

      {isLoading ? (
        <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data ? (
        <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <MetricCard
            compact
            label={t('positions.metrics.positions')}
            value={String(data.positionCount)}
            icon={Briefcase}
          />
          <MetricCard
            compact
            label={t('positions.metrics.openPositions')}
            value={String(data.openPositions)}
            icon={ClipboardList}
          />
          <MetricCard
            compact
            label={t('positions.metrics.templateLinked')}
            value={String(data.templateLinked)}
            icon={FileCheck2}
          />
          <MetricCard
            compact
            label={t('positions.metrics.evaluationComplete')}
            value={String(data.evaluationComplete)}
            icon={Scale}
          />
        </div>
      ) : null}

      <section>
        <SectionHeader title={t('positions.sections.list')} />
        <div className="mt-3 md:hidden">
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: POSITION_SKELETON_COUNT }, (_, index) => (
                <Skeleton key={index} className="h-16 w-full rounded-xl" />
              ))}
            </div>
          ) : (
            <DataList
              items={(data?.positions ?? []).map((position) => ({
                id: position.id,
                title: position.name,
                subtitle: `${position.department} · ${position.template}`,
                meta: t('positions.evaluationScore', { score: position.evaluation }),
              }))}
            />
          )}
        </div>

        <div className="mt-3 hidden overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] md:block">
          <div
            className={cn(
              'grid gap-3 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]',
              POSITION_TABLE_GRID_COLS,
            )}
          >
            <div>{t('positions.columns.name')}</div>
            <div>{t('positions.columns.department')}</div>
            <div>{t('positions.columns.template')}</div>
            <div className="text-right">{t('positions.columns.evaluation')}</div>
          </div>
          <ul className="divide-y divide-[var(--color-border)]">
            {isLoading
              ? Array.from({ length: POSITION_SKELETON_COUNT }, (_, index) => (
                  <li
                    key={index}
                    className={cn('grid items-center gap-3 px-4 py-3', POSITION_TABLE_GRID_COLS)}
                  >
                    <Skeleton className="h-4 w-32" />
                    <Skeleton className="h-4 w-28" />
                    <Skeleton className="h-4 w-24" />
                    <Skeleton className="ml-auto h-4 w-12" />
                  </li>
                ))
              : (data?.positions ?? []).map((position) => (
                  <li
                    key={position.id}
                    className={cn('grid items-center gap-3 px-4 py-3', POSITION_TABLE_GRID_COLS)}
                  >
                    <div className="truncate text-sm font-medium">{position.name}</div>
                    <div className="truncate text-sm text-[var(--color-text-secondary)]">
                      {position.department}
                    </div>
                    <div className="truncate text-sm text-[var(--color-text-secondary)]">
                      {position.template}
                    </div>
                    <div className="text-right text-sm font-medium tabular-nums">{position.evaluation}</div>
                  </li>
                ))}
          </ul>
        </div>
      </section>

      <SheetShell
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        title={t('positions.sheet.title')}
        description={t('positions.sheet.description')}
        footer={
          <div className="flex w-full flex-col gap-3">
            <StatusPill tone="neutral" className="self-start">
              {t('common.soon')}
            </StatusPill>
            <Button type="button" className="touch-target w-full" disabled>
              {t('positions.sheet.submit')}
            </Button>
          </div>
        }
      >
        <div className="space-y-4">
          <FormField label={t('positions.sheet.fields.name')} htmlFor="position-name">
            <Input
              id="position-name"
              className="text-base"
              placeholder={t('positions.sheet.placeholders.name')}
              disabled
            />
          </FormField>
          <FormField label={t('positions.sheet.fields.department')} htmlFor="position-department">
            <Input
              id="position-department"
              className="text-base"
              placeholder={t('positions.sheet.placeholders.department')}
              disabled
            />
          </FormField>
          <FormField label={t('positions.sheet.fields.template')} htmlFor="position-template">
            <Input
              id="position-template"
              className="text-base"
              placeholder={t('positions.sheet.placeholders.template')}
              disabled
            />
          </FormField>
        </div>
      </SheetShell>
    </div>
  )
}
