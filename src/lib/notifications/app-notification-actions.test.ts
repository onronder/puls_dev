import { describe, expect, it } from 'vitest'

import {
  buildAppNotificationIssueCsv,
  resolveAppNotificationAction,
} from './app-notification-actions'

import type { AppNotification } from '#/lib/data/app/notifications'

function notification(overrides: Partial<AppNotification> = {}): AppNotification {
  return {
    notificationId: '11111111-1111-4111-8111-111111111111',
    tenantId: 'tenant-1',
    sourceDomain: 'connector_runtime',
    sourceEventKey: 'connector_job_failed',
    sourceTable: 'puls_integration.connector_jobs',
    sourceId: '22222222-2222-4222-8222-222222222222',
    severity: 'error',
    priority: 90,
    targetRoles: ['admin'],
    subjectType: 'connector_job',
    subjectId: '22222222-2222-4222-8222-222222222222',
    titleKey: 'notifications.connectorRuntime.jobFailed.title',
    bodyKey: 'notifications.connectorRuntime.jobFailed.body',
    routeHint: 'connector_runtime.jobs',
    actionKey: 'review_connector_job_failure',
    notificationStatus: 'open',
    safeSummary: {
      safe_error_code: 'runtime_preflight_context_missing',
      provider_api_calls: false,
      credential_readback: false,
    },
    occurredAt: '2026-06-07T10:00:00.000Z',
    expiresAt: null,
    createdAt: '2026-06-07T10:00:01.000Z',
    readAt: null,
    dismissedAt: null,
    isRead: false,
    isDismissed: false,
    isActionRequired: true,
    ...overrides,
  }
}

describe('app notification actions', () => {
  it('routes known ERP connector issues to the exact runtime queue section and keeps CSV export', () => {
    const action = resolveAppNotificationAction(notification())

    expect(action.primaryAction).toMatchObject({
      labelKey: 'notifications.center.goToProcess',
      exactTarget: true,
      target: {
        to: '/verikaynaklari',
        search: {
          tab: 'activity',
          focus: 'erp-runtime-queue',
        },
      },
    })
    expect(action.canExportIssueCsv).toBe(true)
  })

  it('routes rollback readiness notifications to the exact rollback readiness section', () => {
    const action = resolveAppNotificationAction(
      notification({
        sourceEventKey: 'import_apply_rollback_worker_ready',
        severity: 'warning',
        routeHint: 'connector_runtime.rollback_worker_readiness',
      }),
    )

    expect(action.primaryAction).toMatchObject({
      exactTarget: true,
      target: {
        to: '/verikaynaklari',
        search: {
          tab: 'previewApply',
          focus: 'erp-guarded-update-rollback-worker-readiness',
        },
      },
    })
    expect(action.canExportIssueCsv).toBe(false)
  })

  it('routes file import upload notifications to the import preview section', () => {
    const action = resolveAppNotificationAction(
      notification({
        sourceEventKey: 'file_import_uploaded',
        severity: 'success',
        routeHint: 'connector_runtime.file_import',
      }),
    )

    expect(action.primaryAction).toMatchObject({
      exactTarget: true,
      target: {
        to: '/verikaynaklari',
        search: {
          tab: 'previewApply',
          focus: 'erp-import-preview',
        },
      },
    })
    expect(action.canExportIssueCsv).toBe(false)
  })

  it('routes workflow leave approval notifications to the leave process', () => {
    const action = resolveAppNotificationAction(
      notification({
        sourceDomain: 'puls_workflow',
        sourceEventKey: 'leave_approval_requested',
        sourceTable: 'puls_workflow.approval_requests',
        titleKey: 'notifications.workflow.leaveApprovalRequested.title',
        bodyKey: 'notifications.workflow.leaveApprovalRequested.body',
        routeHint: 'workflow.leave',
        actionKey: 'review_workflow_approval',
        severity: 'warning',
      }),
    )

    expect(action.primaryAction).toMatchObject({
      exactTarget: true,
      target: {
        to: '/izin',
      },
    })
    expect(action.canExportIssueCsv).toBe(false)
  })

  it('routes workflow expense decision notifications to the expense process', () => {
    const action = resolveAppNotificationAction(
      notification({
        sourceDomain: 'puls_workflow',
        sourceEventKey: 'expense_claim_rejected',
        sourceTable: 'puls_workflow.expense_claims',
        titleKey: 'notifications.workflow.expenseRejected.title',
        bodyKey: 'notifications.workflow.expenseRejected.body',
        routeHint: 'workflow.expense',
        actionKey: 'view_workflow_request',
        severity: 'info',
      }),
    )

    expect(action.primaryAction).toMatchObject({
      exactTarget: true,
      target: {
        to: '/masraf',
      },
    })
    expect(action.canExportIssueCsv).toBe(false)
  })

  it('uses CSV export instead of a vague route for unknown ERP error notifications', () => {
    const action = resolveAppNotificationAction(
      notification({
        sourceEventKey: 'connector_custom_failed',
        routeHint: 'connector_runtime.unknown',
      }),
    )

    expect(action.primaryAction).toBeNull()
    expect(action.canExportIssueCsv).toBe(true)
  })

  it('builds a safe issue CSV from notification metadata and safe summary only', () => {
    const csv = buildAppNotificationIssueCsv(notification(), {
      title: 'Bağlantı işlemi başarısız oldu',
      body: 'ERP bağlantısındaki bir işlem tamamlanamadı.',
      severity: 'Hata',
      source: 'ERP bağlantısı',
      status: 'Okunmadı',
      received: 'bugün',
    })

    expect(csv).toContain('"field","value"')
    expect(csv).toContain('"title","Bağlantı işlemi başarısız oldu"')
    expect(csv).toContain('"safe_summary.safe_error_code","runtime_preflight_context_missing"')
    expect(csv).not.toContain('raw_payload')
    expect(csv).not.toContain('credential_value')
  })
})
