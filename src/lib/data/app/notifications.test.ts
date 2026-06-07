import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  appNotificationRealtimeTopic,
  dismissAppNotification,
  fetchAppNotificationPage,
  fetchAppNotificationSummary,
  mapAppNotificationRealtimeSignal,
  markAllAppNotificationsRead,
  markAppNotificationRead,
  subscribeToAppNotificationSignals,
} from '#/lib/data/app/notifications'

vi.mock('#/lib/data/client', () => ({
  pulsApp: vi.fn(),
}))

vi.mock('#/lib/supabase', () => ({
  supabase: {
    realtime: {
      setAuth: vi.fn(() => Promise.resolve()),
    },
    channel: vi.fn(),
    removeChannel: vi.fn(() => Promise.resolve('ok')),
  },
}))

import { pulsApp } from '#/lib/data/client'
import { supabase } from '#/lib/supabase'

const appClient = vi.mocked(pulsApp)
const realtimeClient = vi.mocked(supabase)

type RpcResult = {
  data?: unknown
  error?: unknown
}

function rpcClient(resultByName: Record<string, RpcResult>) {
  return {
    rpc: vi.fn((name: string) => {
      const result = resultByName[name] ?? { data: null, error: null }
      return {
        maybeSingle: vi.fn(() => {
          throw new Error('notification RPC adapters must not request singular rows')
        }),
        then(
          onFulfilled: (value: RpcResult) => unknown,
          onRejected?: (reason: unknown) => unknown,
        ) {
          return Promise.resolve({
            data: result.data ?? null,
            error: result.error ?? null,
          }).then(onFulfilled, onRejected)
        },
      }
    }),
  }
}

describe('app notification data adapter', () => {
  afterEach(() => {
    vi.clearAllMocks()
  })

  it('maps the summary RPC into camelCase UI state', async () => {
    const client = rpcClient({
      get_app_notification_summary: {
        data: [
          {
            tenant_id: 'tenant-1',
            employee_id: 'employee-1',
            visible_count: 7,
            unread_count: 3,
            dismissed_count: 1,
            action_required_count: 2,
            warning_count: 1,
            critical_count: 1,
            latest_occurred_at: '2026-06-07T10:00:00Z',
            notification_ledger_enabled: true,
            notification_realtime_enabled: false,
            external_delivery_enabled: false,
            next_action_key: 'add_notification_realtime_pr16_9_4',
            safe_summary: { notification_center_ui_enabled: true },
          },
        ],
      },
    })
    appClient.mockReturnValue(client as never)

    await expect(fetchAppNotificationSummary()).resolves.toMatchObject({
      tenantId: 'tenant-1',
      employeeId: 'employee-1',
      visibleCount: 7,
      unreadCount: 3,
      criticalCount: 1,
      notificationLedgerEnabled: true,
      notificationRealtimeEnabled: false,
      externalDeliveryEnabled: false,
    })
    expect(client.rpc).toHaveBeenCalledWith('get_app_notification_summary', {
      p_source_domain: null,
    })
  })

  it('maps a cursor page and keeps the cursor from the RPC boundary', async () => {
    const cursor = {
      priority: 90,
      occurred_at: '2026-06-07T10:00:00Z',
      notification_id: 'notification-1',
    }
    const client = rpcClient({
      list_app_notifications_page: {
        data: [
          {
            notification_id: 'notification-1',
            tenant_id: 'tenant-1',
            source_domain: 'connector_runtime',
            source_event_key: 'connector_job_failed',
            source_table: 'puls_integration.connector_jobs',
            source_id: 'job-1',
            severity: 'error',
            priority: 90,
            target_roles: ['admin'],
            subject_type: 'connector_job',
            subject_id: 'job-1',
            title_key: 'notifications.connectorRuntime.jobFailed.title',
            body_key: 'notifications.connectorRuntime.jobFailed.body',
            route_hint: 'connector_runtime.jobs',
            action_key: 'review_connector_job_failure',
            notification_status: 'active',
            safe_summary: { source_domain: 'connector_runtime' },
            occurred_at: '2026-06-07T10:00:00Z',
            expires_at: null,
            created_at: '2026-06-07T10:00:01Z',
            read_at: null,
            dismissed_at: null,
            is_read: false,
            is_dismissed: false,
            is_action_required: true,
            page_has_more: true,
            next_cursor: cursor,
          },
        ],
      },
    })
    appClient.mockReturnValue(client as never)

    const page = await fetchAppNotificationPage({
      filter: 'action_required',
      cursor: null,
      limit: 20,
    })

    expect(page.hasMore).toBe(true)
    expect(page.nextCursor).toEqual(cursor)
    expect(page.items[0]).toMatchObject({
      notificationId: 'notification-1',
      sourceDomain: 'connector_runtime',
      severity: 'error',
      isActionRequired: true,
    })
    expect(client.rpc).toHaveBeenCalledWith('list_app_notifications_page', {
      p_limit: 20,
      p_filter: 'action_required',
      p_source_domain: null,
      p_cursor: null,
    })
  })

  it('calls read-state RPCs with notification scoped parameters', async () => {
    const client = rpcClient({
      mark_app_notification_read: {
        data: [
          {
            notification_id: 'notification-1',
            employee_id: 'employee-1',
            read_at: '2026-06-07T10:00:00Z',
            dismissed_at: null,
            is_read: true,
            is_dismissed: false,
          },
        ],
      },
      dismiss_app_notification: {
        data: [
          {
            notification_id: 'notification-1',
            employee_id: 'employee-1',
            read_at: '2026-06-07T10:00:00Z',
            dismissed_at: '2026-06-07T10:01:00Z',
            is_read: true,
            is_dismissed: true,
          },
        ],
      },
      mark_all_app_notifications_read: {
        data: [
          {
            marked_count: 3,
            unread_remaining_count: 0,
            read_at: '2026-06-07T10:00:00Z',
          },
        ],
      },
    })
    appClient.mockReturnValue(client as never)

    await expect(markAppNotificationRead('notification-1')).resolves.toMatchObject({
      notificationId: 'notification-1',
      isRead: true,
    })
    await expect(dismissAppNotification('notification-1')).resolves.toMatchObject({
      notificationId: 'notification-1',
      isDismissed: true,
    })
    await expect(markAllAppNotificationsRead()).resolves.toMatchObject({
      markedCount: 3,
      unreadRemainingCount: 0,
    })

    expect(client.rpc).toHaveBeenCalledWith('mark_app_notification_read', {
      p_notification_id: 'notification-1',
    })
    expect(client.rpc).toHaveBeenCalledWith('dismiss_app_notification', {
      p_notification_id: 'notification-1',
    })
    expect(client.rpc).toHaveBeenCalledWith('mark_all_app_notifications_read', {
      p_source_domain: null,
    })
  })

  it('maps only minimal realtime broadcast hints', () => {
    expect(appNotificationRealtimeTopic('tenant-1')).toBe(
      'puls_app:notification-center:tenant:tenant-1',
    )

    expect(
      mapAppNotificationRealtimeSignal({
        payload: {
          notification_id: 'notification-1',
          source_domain: 'connector_runtime',
          source_event_key: 'connector_job_failed',
          severity: 'error',
          occurred_at: '2026-06-07T10:00:00Z',
          count_hint: 1,
        },
      }),
    ).toEqual({
      notificationId: 'notification-1',
      sourceDomain: 'connector_runtime',
      sourceEventKey: 'connector_job_failed',
      severity: 'error',
      occurredAt: '2026-06-07T10:00:00Z',
      countHint: 1,
    })

    expect(
      mapAppNotificationRealtimeSignal({
        payload: {
          notification_id: 'notification-1',
          safe_summary: { raw_payload_readback: false },
        },
      }),
    ).toBeNull()

    expect(
      mapAppNotificationRealtimeSignal({
        payload: {
          notification_id: 'notification-1',
          credential_value: 'secret',
        },
      }),
    ).toBeNull()
  })

  it('subscribes to a private tenant realtime channel and falls back safely', () => {
    let broadcastHandler: (payload: unknown) => void = () => {}
    let statusHandler: (status: string) => void = () => {}
    const channel = {
      on: vi.fn(
        (_type: string, _filter: Record<string, string>, handler: (payload: unknown) => void) => {
          broadcastHandler = handler
          return channel
        },
      ),
      subscribe: vi.fn((handler: (status: string) => void) => {
        statusHandler = handler
        return channel
      }),
    }
    const onSignal = vi.fn()
    const onStatusChange = vi.fn()

    realtimeClient.channel.mockReturnValue(channel as never)

    const subscription = subscribeToAppNotificationSignals({
      tenantId: 'tenant-1',
      enabled: true,
      onSignal,
      onStatusChange,
    })

    expect(realtimeClient.realtime.setAuth).toHaveBeenCalled()
    expect(realtimeClient.channel).toHaveBeenCalledWith(
      'puls_app:notification-center:tenant:tenant-1',
      {
        config: {
          private: true,
          broadcast: { self: false, ack: false },
        },
      },
    )

    statusHandler('SUBSCRIBED')
    expect(onStatusChange).toHaveBeenLastCalledWith('connected')

    broadcastHandler({
      payload: {
        notification_id: 'notification-1',
        source_domain: 'connector_runtime',
        source_event_key: 'connector_job_failed',
        severity: 'error',
        occurred_at: '2026-06-07T10:00:00Z',
        count_hint: 1,
      },
    })
    expect(onSignal).toHaveBeenCalledWith(
      expect.objectContaining({ notificationId: 'notification-1' }),
    )

    statusHandler('CHANNEL_ERROR')
    expect(onStatusChange).toHaveBeenLastCalledWith('fallback')

    subscription.unsubscribe()
    expect(realtimeClient.removeChannel).toHaveBeenCalledWith(channel)
  })
})
