import {
  AlertTriangle,
  Braces,
  CheckCircle2,
  ClipboardCheck,
  FileSpreadsheet,
  Globe2,
  Info,
  Plug,
  SearchCheck,
  type LucideIcon,
} from 'lucide-react'

import type { StatusTone } from '#/components/puls/StatusPill'
import type { ErpOverview } from '#/lib/data'

export const ERP_WORKBENCH_TABS = [
  'setup',
  'fields',
  'check',
  'credentials',
  'previewApply',
  'activity',
] as const

export type ErpWorkbenchTab = (typeof ERP_WORKBENCH_TABS)[number]
export type ConnectorStatus = ErpOverview['readiness']['status']
export type ConnectorActivityEvent = ErpOverview['activityTimeline'][number]
export type ConnectorSyncLevel = ConnectorActivityEvent['level']
export type ConnectorProviderOption = ErpOverview['providerOptions'][number]
export type DataSourceSummary = ErpOverview['dataSources'][number]
export type ConnectorDomainOwnership = ErpOverview['domainOwnership'][number]
export type ConnectorJourneyStepId =
  | 'source'
  | 'fields'
  | 'preview'
  | 'review'
  | 'approve'
  | 'activity'

export type ConnectorJourneyMetric = {
  labelKey: string
  value: string
  hint?: string
}

export type ConnectorJourneyAction = {
  label: string
  icon: LucideIcon
  onClick: () => void
  variant?: 'default' | 'outline'
}

export type ConnectorJourneyStep = {
  id: ConnectorJourneyStepId
  icon: LucideIcon
  status: ConnectorStatus
  titleKey: string
  descriptionKey: string
  evidenceKey: string
  detailTab: ErpWorkbenchTab
  detailTargetId: string
  primaryAction: ConnectorJourneyAction
  metrics: ConnectorJourneyMetric[]
}

export function connectorJourneyStepFromTarget(
  tab?: ErpWorkbenchTab,
  targetId?: string,
): ConnectorJourneyStepId | null {
  if (targetId?.includes('runtime') || tab === 'activity') return 'activity'
  if (
    targetId?.includes('controlled-apply') ||
    targetId?.includes('rollback-approval') ||
    targetId?.includes('rollback-worker') ||
    targetId?.includes('worker-apply')
  ) {
    return 'approve'
  }
  if (
    targetId?.includes('apply-readiness') ||
    targetId?.includes('change-set') ||
    targetId?.includes('guarded-update')
  ) {
    return 'review'
  }
  if (targetId?.includes('import-preview') || tab === 'previewApply') return 'preview'
  if (targetId?.includes('mapping') || tab === 'fields' || tab === 'check') return 'fields'
  if (tab === 'credentials' || tab === 'setup') return 'source'
  return null
}

export function readinessTone(status: ConnectorStatus): StatusTone {
  if (status === 'ready') return 'success'
  if (status === 'partial') return 'warning'
  return 'neutral'
}

export function syncLogTone(level: ConnectorSyncLevel): string {
  switch (level) {
    case 'success':
      return 'bg-[var(--color-success-soft)] text-[var(--color-success)]'
    case 'warning':
      return 'bg-[var(--color-warning-soft)] text-[var(--color-warning)]'
    case 'error':
      return 'bg-[var(--color-danger-soft)] text-[var(--color-danger)]'
    default:
      return 'bg-[var(--color-primary-soft)] text-[var(--color-info)]'
  }
}

export function runtimeJobStatusTone(level: ConnectorSyncLevel): StatusTone {
  if (level === 'success') return 'success'
  if (level === 'error') return 'danger'
  if (level === 'warning') return 'warning'
  return 'info'
}

export function applyChangeSetRiskTone(
  riskClass: ErpOverview['applyChangeSet']['sampleItems'][number]['riskClass'],
  blocked: boolean,
): StatusTone {
  if (riskClass === 'create_only') return 'success'
  if (riskClass === 'no_change_skip') return 'neutral'
  if (riskClass === 'destructive_equivalent' || riskClass === 'stale_preview') return 'danger'
  if (blocked) return 'warning'
  return 'info'
}

export function guardedUpdateFieldTone(
  fieldClass: ErpOverview['guardedUpdateEvidence']['sampleFieldDiffs'][number]['fieldClass'],
  staleBlocked: boolean,
): StatusTone {
  if (staleBlocked || fieldClass === 'destructive_equivalent') return 'danger'
  if (fieldClass === 'sensitive') return 'warning'
  return 'success'
}

export function domainOwnershipTone(status: ConnectorDomainOwnership['status']): StatusTone {
  if (status === 'owned_by_current') return 'success'
  if (status === 'owned_by_other') return 'warning'
  return 'neutral'
}

export function SyncLogIcon({ level }: { level: ConnectorSyncLevel }) {
  const className = 'h-4 w-4'
  if (level === 'success') return <CheckCircle2 className={className} aria-hidden />
  if (level === 'warning') return <AlertTriangle className={className} aria-hidden />
  if (level === 'error') return <AlertTriangle className={className} aria-hidden />
  return <Info className={className} aria-hidden />
}

export function formatActivityDetailValue(
  value: ConnectorActivityEvent['detailItems'][number]['value'],
  translate: (key: string) => string,
  labelKey?: string,
) {
  if (typeof value === 'boolean') {
    return translate(value ? 'erp.activityTimeline.values.yes' : 'erp.activityTimeline.values.no')
  }
  if (labelKey === 'erp.activityTimeline.details.authMode') {
    return translate(`erp.authModes.${value}`)
  }
  if (labelKey === 'erp.activityTimeline.details.credentialState') {
    return translate(`erp.credentialBoundary.states.${value}`)
  }
  return String(value)
}

export function formatDateTime(value: string | null, locale: string, fallback: string): string {
  if (!value) return fallback
  try {
    return new Intl.DateTimeFormat(locale, {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date(value))
  } catch {
    return fallback
  }
}

export function dataSourceDisplayName(
  source: DataSourceSummary,
  translate: (key: string, options?: Record<string, unknown>) => string,
): string {
  return source.displayName.trim() || translate(source.providerLabelKey)
}

export function formatDataSourceScope(
  source: DataSourceSummary,
  translate: (key: string, options?: Record<string, unknown>) => string,
): string {
  if (source.scope.length === 0) return translate('erp.dataSources.values.noScope')
  return source.scope
    .map((scope) => translate(`erp.dataSources.scopeValues.${scope}`, { defaultValue: scope }))
    .join(', ')
}

export function DataSourceActionIcon({
  action,
  className,
}: {
  action: DataSourceSummary['primaryAction']
  className?: string
}) {
  if (action === 'upload_file') return <FileSpreadsheet className={className} aria-hidden />
  if (action === 'run_preview') return <SearchCheck className={className} aria-hidden />
  if (action === 'review_results') return <ClipboardCheck className={className} aria-hidden />
  if (action === 'open_details') return <SearchCheck className={className} aria-hidden />
  return <Plug className={className} aria-hidden />
}

export function ProviderOptionIcon({ id }: { id: ConnectorProviderOption['id'] }) {
  const className = 'h-5 w-5'
  if (id === 'csv_import') return <FileSpreadsheet className={className} aria-hidden />
  if (id === 'custom_api') return <Braces className={className} aria-hidden />
  if (id === 'logo') return <Globe2 className={className} aria-hidden />
  return <Plug className={className} aria-hidden />
}
