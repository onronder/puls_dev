import type { AppNotification } from '#/lib/data/app/notifications'

export type ErpNotificationTab =
  | 'setup'
  | 'fields'
  | 'check'
  | 'credentials'
  | 'previewApply'
  | 'activity'

export type AppNotificationActionTarget =
  | {
      to: '/erp'
      search: {
        tab: ErpNotificationTab
        focus: string
      }
    }
  | {
      to: '/dashboard'
    }

export type AppNotificationPrimaryAction = {
  kind: 'route'
  labelKey: string
  target: AppNotificationActionTarget
  exactTarget: boolean
}

export type AppNotificationActionResolution = {
  primaryAction: AppNotificationPrimaryAction | null
  canExportIssueCsv: boolean
  exportFileName: string
}

type ConnectorRuntimeTarget = {
  tab: ErpNotificationTab
  focus: string
  exactTarget: boolean
}

const connectorRuntimeEventTargets: Record<string, ConnectorRuntimeTarget> = {
  connector_job_failed: {
    tab: 'activity',
    focus: 'erp-runtime-queue',
    exactTarget: true,
  },
  connector_job_dead_letter: {
    tab: 'activity',
    focus: 'erp-runtime-queue',
    exactTarget: true,
  },
  runtime_preflight_failed: {
    tab: 'activity',
    focus: 'erp-runtime-queue',
    exactTarget: true,
  },
  import_apply_create_only_completed: {
    tab: 'previewApply',
    focus: 'erp-controlled-apply',
    exactTarget: true,
  },
  import_apply_guarded_update_completed: {
    tab: 'previewApply',
    focus: 'erp-controlled-apply',
    exactTarget: true,
  },
  import_apply_rollback_completed: {
    tab: 'previewApply',
    focus: 'erp-guarded-update-rollback-worker-apply',
    exactTarget: true,
  },
  import_apply_rollback_preview_ready: {
    tab: 'previewApply',
    focus: 'erp-guarded-update-rollback-preview',
    exactTarget: true,
  },
  import_apply_rollback_approval_recorded: {
    tab: 'previewApply',
    focus: 'erp-guarded-update-rollback-approval',
    exactTarget: true,
  },
  import_apply_rollback_worker_ready: {
    tab: 'previewApply',
    focus: 'erp-guarded-update-rollback-worker-readiness',
    exactTarget: true,
  },
}

const connectorRuntimeRouteHintTargets: Record<string, ConnectorRuntimeTarget> = {
  'connector_runtime.jobs': {
    tab: 'activity',
    focus: 'erp-runtime-queue',
    exactTarget: false,
  },
  'connector_runtime.preflight': {
    tab: 'activity',
    focus: 'erp-runtime-queue',
    exactTarget: false,
  },
  'connector_runtime.apply': {
    tab: 'previewApply',
    focus: 'erp-controlled-apply',
    exactTarget: false,
  },
  'connector_runtime.rollback': {
    tab: 'previewApply',
    focus: 'erp-guarded-update-rollback-worker-apply',
    exactTarget: false,
  },
  'connector_runtime.rollback_preview': {
    tab: 'previewApply',
    focus: 'erp-guarded-update-rollback-preview',
    exactTarget: false,
  },
  'connector_runtime.rollback_approval': {
    tab: 'previewApply',
    focus: 'erp-guarded-update-rollback-approval',
    exactTarget: false,
  },
  'connector_runtime.rollback_worker_readiness': {
    tab: 'previewApply',
    focus: 'erp-guarded-update-rollback-worker-readiness',
    exactTarget: false,
  },
}

const issueSeverities = new Set(['critical', 'error'])

function isIssueNotification(notification: AppNotification) {
  return (
    issueSeverities.has(notification.severity) ||
    notification.sourceEventKey.includes('failed') ||
    notification.sourceEventKey.includes('dead_letter')
  )
}

function resolveConnectorRuntimeTarget(notification: AppNotification): ConnectorRuntimeTarget | null {
  return (
    connectorRuntimeEventTargets[notification.sourceEventKey] ??
    (notification.routeHint ? connectorRuntimeRouteHintTargets[notification.routeHint] : null)
  )
}

export function resolveAppNotificationAction(
  notification: AppNotification,
): AppNotificationActionResolution {
  const canExportIssueCsv = isIssueNotification(notification)
  const exportFileName = buildAppNotificationExportFileName(notification)

  if (notification.sourceDomain === 'connector_runtime') {
    const target = resolveConnectorRuntimeTarget(notification)

    if (target && (target.exactTarget || !canExportIssueCsv)) {
      return {
        primaryAction: {
          kind: 'route',
          labelKey: 'notifications.center.goToProcess',
          target: {
            to: '/erp',
            search: {
              tab: target.tab,
              focus: target.focus,
            },
          },
          exactTarget: target.exactTarget,
        },
        canExportIssueCsv,
        exportFileName,
      }
    }

    return {
      primaryAction: null,
      canExportIssueCsv,
      exportFileName,
    }
  }

  return {
    primaryAction: {
      kind: 'route',
      labelKey: 'notifications.center.goToProcess',
      target: {
        to: '/dashboard',
      },
      exactTarget: false,
    },
    canExportIssueCsv,
    exportFileName,
  }
}

function normalizeFileNamePart(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

export function buildAppNotificationExportFileName(
  notification: Pick<AppNotification, 'sourceEventKey' | 'notificationId'>,
  now = new Date(),
) {
  const datePart = now.toISOString().slice(0, 10)
  const eventPart = normalizeFileNamePart(notification.sourceEventKey) || 'notification'
  return `puls-notification-${eventPart}-${datePart}-${notification.notificationId.slice(0, 8)}.csv`
}

function csvEscape(value: unknown) {
  const text = value === null || value === undefined ? '' : String(value)
  return `"${text.replace(/"/g, '""')}"`
}

export type AppNotificationIssueCsvCopy = {
  title: string
  body: string
  severity: string
  source: string
  status: string
  received: string
}

export function buildAppNotificationIssueCsv(
  notification: AppNotification,
  copy: AppNotificationIssueCsvCopy,
) {
  const rows: Array<[string, unknown]> = [
    ['title', copy.title],
    ['body', copy.body],
    ['severity', copy.severity],
    ['source', copy.source],
    ['status', copy.status],
    ['received', copy.received],
    ['notification_id', notification.notificationId],
    ['source_domain', notification.sourceDomain],
    ['source_event_key', notification.sourceEventKey],
    ['source_table', notification.sourceTable],
    ['source_id', notification.sourceId],
    ['route_hint', notification.routeHint],
    ['action_key', notification.actionKey],
    ['subject_type', notification.subjectType],
    ['subject_id', notification.subjectId],
    ['occurred_at', notification.occurredAt],
    ['created_at', notification.createdAt],
  ]

  for (const key of Object.keys(notification.safeSummary).sort()) {
    const value = notification.safeSummary[key]
    rows.push([`safe_summary.${key}`, typeof value === 'object' ? JSON.stringify(value) : value])
  }

  return `\uFEFF${['field', 'value'].map(csvEscape).join(',')}\n${
    rows.map((row) => row.map(csvEscape).join(',')).join('\n')
  }\n`
}
