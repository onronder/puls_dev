import { pulsApp } from '#/lib/data/client'
import { adapterError, fromSupabaseError } from '#/lib/data/errors'
import { supabase } from '#/lib/supabase'

export type NotificationCenterFilter = 'all' | 'unread' | 'action_required'

export type AppNotificationSeverity = 'info' | 'success' | 'warning' | 'error' | 'critical'

export type AppNotificationRealtimeStatus = 'disabled' | 'connecting' | 'connected' | 'fallback'

export type AppNotificationRealtimeSignal = {
  notificationId: string | null
  sourceDomain: string | null
  sourceEventKey: string | null
  severity: AppNotificationSeverity | null
  occurredAt: string | null
  countHint: number | null
}

export type AppNotificationSignalSubscription = {
  topic: string | null
  unsubscribe: () => void
}

export type AppNotificationCursor = {
  priority: number
  occurred_at: string
  notification_id: string
}

export type AppNotificationSummary = {
  tenantId: string | null
  employeeId: string | null
  visibleCount: number
  unreadCount: number
  dismissedCount: number
  actionRequiredCount: number
  warningCount: number
  criticalCount: number
  latestOccurredAt: string | null
  notificationLedgerEnabled: boolean
  notificationRealtimeEnabled: boolean
  externalDeliveryEnabled: boolean
  nextActionKey: string | null
  safeSummary: Record<string, unknown>
}

export type AppNotification = {
  notificationId: string
  tenantId: string
  sourceDomain: string
  sourceEventKey: string
  sourceTable: string | null
  sourceId: string | null
  severity: AppNotificationSeverity
  priority: number
  targetRoles: string[]
  subjectType: string | null
  subjectId: string | null
  titleKey: string
  bodyKey: string | null
  routeHint: string | null
  actionKey: string | null
  notificationStatus: string
  safeSummary: Record<string, unknown>
  occurredAt: string
  expiresAt: string | null
  createdAt: string
  readAt: string | null
  dismissedAt: string | null
  isRead: boolean
  isDismissed: boolean
  isActionRequired: boolean
}

export type AppNotificationPage = {
  items: AppNotification[]
  hasMore: boolean
  nextCursor: AppNotificationCursor | null
}

export type NotificationReadState = {
  notificationId: string
  employeeId: string
  readAt: string | null
  dismissedAt: string | null
  isRead: boolean
  isDismissed: boolean
}

export type MarkAllNotificationsReadResult = {
  markedCount: number
  unreadRemainingCount: number
  readAt: string
}

type NotificationSummaryRow = {
  tenant_id?: string | null
  employee_id?: string | null
  visible_count?: number | null
  unread_count?: number | null
  dismissed_count?: number | null
  action_required_count?: number | null
  warning_count?: number | null
  critical_count?: number | null
  latest_occurred_at?: string | null
  notification_ledger_enabled?: boolean | null
  notification_realtime_enabled?: boolean | null
  external_delivery_enabled?: boolean | null
  next_action_key?: string | null
  safe_summary?: Record<string, unknown> | null
}

type NotificationPageRow = {
  notification_id: string
  tenant_id: string
  source_domain: string
  source_event_key: string
  source_table?: string | null
  source_id?: string | null
  severity: AppNotificationSeverity
  priority: number
  target_roles?: string[] | null
  subject_type?: string | null
  subject_id?: string | null
  title_key: string
  body_key?: string | null
  route_hint?: string | null
  action_key?: string | null
  notification_status: string
  safe_summary?: Record<string, unknown> | null
  occurred_at: string
  expires_at?: string | null
  created_at: string
  read_at?: string | null
  dismissed_at?: string | null
  is_read?: boolean | null
  is_dismissed?: boolean | null
  is_action_required?: boolean | null
  page_has_more?: boolean | null
  next_cursor?: AppNotificationCursor | null
}

type NotificationReadStateRow = {
  notification_id: string
  employee_id: string
  read_at?: string | null
  dismissed_at?: string | null
  is_read?: boolean | null
  is_dismissed?: boolean | null
}

type MarkAllNotificationsReadRow = {
  marked_count?: number | null
  unread_remaining_count?: number | null
  read_at: string
}

const APP_NOTIFICATION_REALTIME_EVENT = 'app_notification_hint'

const appNotificationSignalAllowedKeys = new Set([
  'notification_id',
  'source_domain',
  'source_event_key',
  'severity',
  'occurred_at',
  'count_hint',
])

const appNotificationSignalBlockedKeys = [
  'safe_summary',
  'payload',
  'raw_payload',
  'provider_response',
  'credential',
  'credential_value',
  'before_value',
  'after_value',
  'field_value',
  'snapshot_payload',
]

function stringOrNull(value: unknown) {
  return typeof value === 'string' && value.length > 0 ? value : null
}

function severityOrNull(value: unknown): AppNotificationSeverity | null {
  if (
    value === 'info' ||
    value === 'success' ||
    value === 'warning' ||
    value === 'error' ||
    value === 'critical'
  ) {
    return value
  }

  return null
}

function countHintOrNull(value: unknown) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

export function appNotificationRealtimeTopic(tenantId: string): string {
  return `puls_app:notification-center:tenant:${tenantId}`
}

export function mapAppNotificationRealtimeSignal(
  broadcastPayload: unknown,
): AppNotificationRealtimeSignal | null {
  if (!isRecord(broadcastPayload) || !isRecord(broadcastPayload.payload)) {
    return null
  }

  const payload = broadcastPayload.payload
  const keys = Object.keys(payload)

  if (
    keys.some((key) => !appNotificationSignalAllowedKeys.has(key)) ||
    appNotificationSignalBlockedKeys.some((key) => key in payload)
  ) {
    return null
  }

  return {
    notificationId: stringOrNull(payload.notification_id),
    sourceDomain: stringOrNull(payload.source_domain),
    sourceEventKey: stringOrNull(payload.source_event_key),
    severity: severityOrNull(payload.severity),
    occurredAt: stringOrNull(payload.occurred_at),
    countHint: countHintOrNull(payload.count_hint),
  }
}

export function subscribeToAppNotificationSignals({
  tenantId,
  enabled,
  onSignal,
  onStatusChange,
}: {
  tenantId: string | null
  enabled: boolean
  onSignal: (signal: AppNotificationRealtimeSignal) => void
  onStatusChange?: (status: AppNotificationRealtimeStatus) => void
}): AppNotificationSignalSubscription {
  if (!enabled || !tenantId) {
    onStatusChange?.('disabled')
    return {
      topic: null,
      unsubscribe: () => {},
    }
  }

  const topic = appNotificationRealtimeTopic(tenantId)
  let active = true

  onStatusChange?.('connecting')

  void supabase.realtime.setAuth().catch(() => {
    if (active) onStatusChange?.('fallback')
  })

  const channel = supabase
    .channel(topic, {
      config: {
        private: true,
        broadcast: { self: false, ack: false },
      },
    })
    .on('broadcast', { event: APP_NOTIFICATION_REALTIME_EVENT }, (payload) => {
      const signal = mapAppNotificationRealtimeSignal(payload)
      if (signal) onSignal(signal)
    })

  channel.subscribe((status) => {
    if (!active) return

    if (status === 'SUBSCRIBED') {
      onStatusChange?.('connected')
      return
    }

    if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') {
      onStatusChange?.('fallback')
      return
    }

    onStatusChange?.('connecting')
  })

  return {
    topic,
    unsubscribe: () => {
      active = false
      void supabase.removeChannel(channel)
    },
  }
}

function mapSummary(row: NotificationSummaryRow | null): AppNotificationSummary {
  return {
    tenantId: row?.tenant_id ?? null,
    employeeId: row?.employee_id ?? null,
    visibleCount: row?.visible_count ?? 0,
    unreadCount: row?.unread_count ?? 0,
    dismissedCount: row?.dismissed_count ?? 0,
    actionRequiredCount: row?.action_required_count ?? 0,
    warningCount: row?.warning_count ?? 0,
    criticalCount: row?.critical_count ?? 0,
    latestOccurredAt: row?.latest_occurred_at ?? null,
    notificationLedgerEnabled: row?.notification_ledger_enabled ?? false,
    notificationRealtimeEnabled: row?.notification_realtime_enabled ?? false,
    externalDeliveryEnabled: row?.external_delivery_enabled ?? false,
    nextActionKey: row?.next_action_key ?? null,
    safeSummary: row?.safe_summary ?? {},
  }
}

function mapNotification(row: NotificationPageRow): AppNotification {
  return {
    notificationId: row.notification_id,
    tenantId: row.tenant_id,
    sourceDomain: row.source_domain,
    sourceEventKey: row.source_event_key,
    sourceTable: row.source_table ?? null,
    sourceId: row.source_id ?? null,
    severity: row.severity,
    priority: row.priority,
    targetRoles: row.target_roles ?? [],
    subjectType: row.subject_type ?? null,
    subjectId: row.subject_id ?? null,
    titleKey: row.title_key,
    bodyKey: row.body_key ?? null,
    routeHint: row.route_hint ?? null,
    actionKey: row.action_key ?? null,
    notificationStatus: row.notification_status,
    safeSummary: row.safe_summary ?? {},
    occurredAt: row.occurred_at,
    expiresAt: row.expires_at ?? null,
    createdAt: row.created_at,
    readAt: row.read_at ?? null,
    dismissedAt: row.dismissed_at ?? null,
    isRead: row.is_read ?? false,
    isDismissed: row.is_dismissed ?? false,
    isActionRequired: row.is_action_required ?? false,
  }
}

function mapReadState(row: NotificationReadStateRow): NotificationReadState {
  return {
    notificationId: row.notification_id,
    employeeId: row.employee_id,
    readAt: row.read_at ?? null,
    dismissedAt: row.dismissed_at ?? null,
    isRead: row.is_read ?? false,
    isDismissed: row.is_dismissed ?? false,
  }
}

function firstRpcRow<T>(data: unknown): T | null {
  if (Array.isArray(data)) {
    return (data[0] as T | undefined) ?? null
  }

  return (data as T | null) ?? null
}

export async function fetchAppNotificationSummary(): Promise<AppNotificationSummary> {
  const { data, error } = await pulsApp().rpc('get_app_notification_summary', {
    p_source_domain: null,
  })

  if (error) {
    throw fromSupabaseError(error, 'fetchAppNotificationSummary', 'puls_app', 'app_notifications')
  }

  return mapSummary(firstRpcRow<NotificationSummaryRow>(data))
}

export async function fetchAppNotificationPage({
  filter = 'all',
  cursor = null,
  limit = 25,
}: {
  filter?: NotificationCenterFilter
  cursor?: AppNotificationCursor | null
  limit?: number
} = {}): Promise<AppNotificationPage> {
  const { data, error } = await pulsApp().rpc('list_app_notifications_page', {
    p_limit: limit,
    p_filter: filter,
    p_source_domain: null,
    p_cursor: cursor,
  })

  if (error) {
    throw fromSupabaseError(error, 'fetchAppNotificationPage', 'puls_app', 'app_notifications')
  }

  const rows = (data ?? []) as NotificationPageRow[]
  return {
    items: rows.map(mapNotification),
    hasMore: rows.at(0)?.page_has_more ?? false,
    nextCursor: rows.at(0)?.next_cursor ?? null,
  }
}

export async function markAppNotificationRead(
  notificationId: string,
): Promise<NotificationReadState> {
  const { data, error } = await pulsApp().rpc('mark_app_notification_read', {
    p_notification_id: notificationId,
  })

  if (error) {
    throw fromSupabaseError(error, 'markAppNotificationRead', 'puls_app', 'app_notification_reads')
  }

  const row = firstRpcRow<NotificationReadStateRow>(data)
  if (!row) throw adapterError('markAppNotificationRead', 'empty_rpc_result')

  return mapReadState(row)
}

export async function dismissAppNotification(
  notificationId: string,
): Promise<NotificationReadState> {
  const { data, error } = await pulsApp().rpc('dismiss_app_notification', {
    p_notification_id: notificationId,
  })

  if (error) {
    throw fromSupabaseError(error, 'dismissAppNotification', 'puls_app', 'app_notification_reads')
  }

  const row = firstRpcRow<NotificationReadStateRow>(data)
  if (!row) throw adapterError('dismissAppNotification', 'empty_rpc_result')

  return mapReadState(row)
}

export async function markAllAppNotificationsRead(): Promise<MarkAllNotificationsReadResult> {
  const { data, error } = await pulsApp().rpc('mark_all_app_notifications_read', {
    p_source_domain: null,
  })

  if (error) {
    throw fromSupabaseError(
      error,
      'markAllAppNotificationsRead',
      'puls_app',
      'app_notification_reads',
    )
  }

  const row = firstRpcRow<MarkAllNotificationsReadRow>(data)
  if (!row) throw adapterError('markAllAppNotificationsRead', 'empty_rpc_result')

  return {
    markedCount: row.marked_count ?? 0,
    unreadRemainingCount: row.unread_remaining_count ?? 0,
    readAt: row.read_at,
  }
}
