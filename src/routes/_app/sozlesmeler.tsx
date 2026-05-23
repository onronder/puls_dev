import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import {
  AlertTriangle,
  Bell,
  Eye,
  FileSignature,
  FileText,
  ShieldCheck,
  Upload,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { DataList } from '#/components/puls/DataList'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import { fetchContractsOverview, type ContractsOverview } from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/sozlesmeler')({
  head: () => ({
    meta: [
      { title: i18n.t('contractsSetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('contractsSetup.meta.description'),
      },
    ],
  }),
  component: SozlesmelerPage,
})

const CONTRACT_SKELETON_COUNT = 4
const CONTRACT_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)_minmax(0,88px)_minmax(0,88px)_minmax(0,80px)_minmax(0,100px)]'

function formatContractDate(isoDate: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(`${isoDate}T12:00:00`))
}

function signatureTone(status: ContractsOverview['contracts'][number]['signed']): StatusTone {
  return status === 'signed' ? 'success' : 'warning'
}

function riskTone(status: ContractsOverview['contracts'][number]['risk']): StatusTone {
  if (status === 'ok') return 'success'
  if (status === 'expiring') return 'warning'
  return 'info'
}

function EmployeeAvatar({ initials }: { initials: string }) {
  return (
    <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-[11px] font-semibold text-[var(--color-primary)]">
      {initials}
    </span>
  )
}

function SozlesmelerPage() {
  const { t, i18n: i18nInstance } = useTranslation()
  const { user } = useAuth()
  const [selectedContractId, setSelectedContractId] = useState<string | null>(null)
  const [detailSheetOpen, setDetailSheetOpen] = useState(false)
  const [reminderSheetOpen, setReminderSheetOpen] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['contracts-overview', user?.id],
    queryFn: () => fetchContractsOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const selectedContract = useMemo(() => {
    if (!data?.contracts.length) return undefined
    return (
      data.contracts.find((contract) => contract.id === selectedContractId) ?? data.contracts[0]
    )
  }, [data, selectedContractId])

  const formatEndDate = (contract: ContractsOverview['contracts'][number]) =>
    contract.endDate
      ? formatContractDate(contract.endDate, i18nInstance.language)
      : t('contractsSetup.noEndDate')

  const renderSignaturePill = (status: ContractsOverview['contracts'][number]['signed']) => (
    <StatusPill tone={signatureTone(status)}>{t(`contractsSetup.signature.${status}`)}</StatusPill>
  )

  const renderRiskPill = (status: ContractsOverview['contracts'][number]['risk']) => (
    <StatusPill tone={riskTone(status)}>{t(`contractsSetup.risk.${status}`)}</StatusPill>
  )

  const openDetailSheet = (contractId?: string) => {
    const id = contractId ?? selectedContract?.id
    if (!id) return
    setSelectedContractId(id)
    setDetailSheetOpen(true)
  }

  const openReminderSheet = () => {
    if (selectedContract) {
      setReminderSheetOpen(true)
    }
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('contractsSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('contractsSetup.title')}
        subtitle={t('contractsSetup.description')}
        actions={
          <Button
            type="button"
            className="touch-target w-full sm:w-auto"
            disabled
            title={t('contractsSetup.actions.uploadUnavailable')}
          >
            <Upload className="h-4 w-4" />
            {t('contractsSetup.actions.upload')}
          </Button>
        }
      />

      {isLoading ? (
        <div className="-mx-4 mb-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data ? (
        <div className="-mx-4 mb-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <MetricCard
            compact
            label={t('contractsSetup.metrics.active')}
            value={String(data.activeContractCount)}
            icon={FileText}
          />
          <MetricCard
            compact
            label={t('contractsSetup.metrics.expiringSoon')}
            value={String(data.expiringSoonCount)}
            icon={AlertTriangle}
          />
          <MetricCard
            compact
            label={t('contractsSetup.metrics.pendingSignature')}
            value={String(data.pendingSignatureCount)}
            icon={FileSignature}
          />
          <MetricCard
            compact
            label={t('contractsSetup.metrics.kvkkMissing')}
            value={String(data.kvkkMissingCount)}
            icon={ShieldCheck}
          />
        </div>
      ) : null}

      <section className="mb-6">
        <SectionHeader title={t('contractsSetup.sections.list')} />
        <div className="mt-3 md:hidden">
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: CONTRACT_SKELETON_COUNT }, (_, index) => (
                <Skeleton key={index} className="h-16 w-full rounded-xl" />
              ))}
            </div>
          ) : (
            <DataList
              items={(data?.contracts ?? []).map((contract) => ({
                id: contract.id,
                title: contract.employeeName,
                subtitle: `${t(contract.typeKey)} · ${formatContractDate(contract.startDate, i18nInstance.language)} – ${formatEndDate(contract)}`,
                leading: <EmployeeAvatar initials={contract.initials} />,
                trailing: renderRiskPill(contract.risk),
                onClick: () => openDetailSheet(contract.id),
              }))}
            />
          )}
        </div>

        <div className="mt-3 hidden overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] md:block">
          <div
            className={cn(
              'grid gap-3 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]',
              CONTRACT_TABLE_GRID_COLS,
            )}
          >
            <div>{t('contractsSetup.columns.employee')}</div>
            <div>{t('contractsSetup.columns.type')}</div>
            <div>{t('contractsSetup.columns.start')}</div>
            <div>{t('contractsSetup.columns.end')}</div>
            <div>{t('contractsSetup.columns.signature')}</div>
            <div>{t('contractsSetup.columns.risk')}</div>
          </div>
          <ul className="divide-y divide-[var(--color-border)]">
            {isLoading
              ? Array.from({ length: CONTRACT_SKELETON_COUNT }, (_, index) => (
                  <li
                    key={index}
                    className={cn('grid items-center gap-3 px-4 py-3', CONTRACT_TABLE_GRID_COLS)}
                  >
                    <Skeleton className="h-4 w-32" />
                    <Skeleton className="h-4 w-24" />
                    <Skeleton className="h-4 w-20" />
                    <Skeleton className="h-4 w-20" />
                    <Skeleton className="h-6 w-16 rounded-full" />
                    <Skeleton className="h-6 w-24 rounded-full" />
                  </li>
                ))
              : (data?.contracts ?? []).map((contract) => {
                  const isSelected = selectedContract?.id === contract.id

                  return (
                    <li key={contract.id}>
                      <button
                        type="button"
                        onClick={() => openDetailSheet(contract.id)}
                        className={cn(
                          'grid w-full min-w-0 touch-target items-center gap-3 px-4 py-3 text-left transition-colors',
                          CONTRACT_TABLE_GRID_COLS,
                          isSelected
                            ? 'bg-[var(--color-primary-soft)]'
                            : 'hover:bg-[var(--color-bg-elevated)]',
                        )}
                      >
                        <div className="flex min-w-0 items-center gap-2">
                          <EmployeeAvatar initials={contract.initials} />
                          <span className="truncate text-sm font-medium">{contract.employeeName}</span>
                        </div>
                        <div className="truncate text-sm text-[var(--color-text-secondary)]">
                          {t(contract.typeKey)}
                        </div>
                        <div className="text-sm tabular-nums">
                          {formatContractDate(contract.startDate, i18nInstance.language)}
                        </div>
                        <div className="text-sm tabular-nums">{formatEndDate(contract)}</div>
                        <div>{renderSignaturePill(contract.signed)}</div>
                        <div>{renderRiskPill(contract.risk)}</div>
                      </button>
                    </li>
                  )
                })}
          </ul>
        </div>
      </section>

      <div className="flex flex-col gap-2 sm:flex-row">
        <Button
          type="button"
          variant="outline"
          className="touch-target h-11 flex-1"
          disabled={!selectedContract}
          onClick={() => openDetailSheet()}
        >
          <Eye className="h-4 w-4" />
          {t('contractsSetup.actions.viewDetail')}
        </Button>
        <Button
          type="button"
          variant="outline"
          className="touch-target h-11 flex-1"
          disabled={!selectedContract}
          onClick={openReminderSheet}
        >
          <Bell className="h-4 w-4" />
          {t('contractsSetup.actions.setReminder')}
        </Button>
      </div>

      <SheetShell
        open={detailSheetOpen}
        onOpenChange={setDetailSheetOpen}
        title={t('contractsSetup.detailSheet.title')}
        description={t('contractsSetup.detailSheet.description')}
      >
        {selectedContract ? (
          <dl className="space-y-4 text-sm">
            <div>
              <dt className="text-xs text-[var(--color-text-muted)]">
                {t('contractsSetup.detailSheet.fields.employee')}
              </dt>
              <dd className="mt-1 font-medium">{selectedContract.employeeName}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-text-muted)]">
                {t('contractsSetup.detailSheet.fields.type')}
              </dt>
              <dd className="mt-1">{t(selectedContract.typeKey)}</dd>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <dt className="text-xs text-[var(--color-text-muted)]">
                  {t('contractsSetup.detailSheet.fields.start')}
                </dt>
                <dd className="mt-1 tabular-nums">
                  {formatContractDate(selectedContract.startDate, i18nInstance.language)}
                </dd>
              </div>
              <div>
                <dt className="text-xs text-[var(--color-text-muted)]">
                  {t('contractsSetup.detailSheet.fields.end')}
                </dt>
                <dd className="mt-1 tabular-nums">{formatEndDate(selectedContract)}</dd>
              </div>
            </div>
            <div className="flex flex-wrap gap-3">
              <div>
                <dt className="text-xs text-[var(--color-text-muted)]">
                  {t('contractsSetup.detailSheet.fields.signature')}
                </dt>
                <dd className="mt-2">{renderSignaturePill(selectedContract.signed)}</dd>
              </div>
              <div>
                <dt className="text-xs text-[var(--color-text-muted)]">
                  {t('contractsSetup.detailSheet.fields.risk')}
                </dt>
                <dd className="mt-2">{renderRiskPill(selectedContract.risk)}</dd>
              </div>
            </div>
          </dl>
        ) : null}
      </SheetShell>

      <SheetShell
        open={reminderSheetOpen}
        onOpenChange={setReminderSheetOpen}
        title={t('contractsSetup.reminderSheet.title')}
        description={t('contractsSetup.reminderSheet.description')}
        footer={
          <div className="flex w-full flex-col gap-3">
            <StatusPill tone="neutral" className="self-start">
              {t('common.soon')}
            </StatusPill>
            <Button type="button" variant="outline" className="touch-target w-full" disabled>
              {t('common.readOnlyAction')}
            </Button>
          </div>
        }
      >
        <div className="space-y-4">
          {selectedContract ? (
            <p className="text-sm text-[var(--color-text-secondary)]">
              {selectedContract.employeeName} · {t(selectedContract.typeKey)}
            </p>
          ) : null}
          <FormField
            label={t('contractsSetup.reminderSheet.fields.daysBefore')}
            htmlFor="reminder-days"
          >
            <Input
              id="reminder-days"
              className="text-base"
              placeholder={t('contractsSetup.reminderSheet.placeholders.daysBefore')}
              disabled
            />
          </FormField>
          <p className="text-xs text-[var(--color-text-muted)]">
            {t('contractsSetup.reminderSheet.hint')}
          </p>
        </div>
      </SheetShell>
    </div>
  )
}
