import { pulsApp } from '#/lib/data/client'
import { fromSupabaseError } from '#/lib/data/errors'

export type NotificationCenterFilter = 'all' | 'unread' | 'action_required'

export type AppNotificationSeverity = 'info' | 'success' | 'warning' | 'error' | 'critical'

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

export async function fetchAppNotificationSummary(): Promise<AppNotificationSummary> {
  const { data, error } = await pulsApp()
    .rpc('get_app_notification_summary', { p_source_domain: null })
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'fetchAppNotificationSummary', 'puls_app', 'app_notifications')
  }

  return mapSummary(data as NotificationSummaryRow | null)
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
  const { data, error } = await pulsApp()
    .rpc('mark_app_notification_read', { p_notification_id: notificationId })
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'markAppNotificationRead', 'puls_app', 'app_notification_reads')
  }

  return mapReadState(data as NotificationReadStateRow)
}

export async function dismissAppNotification(
  notificationId: string,
): Promise<NotificationReadState> {
  const { data, error } = await pulsApp()
    .rpc('dismiss_app_notification', { p_notification_id: notificationId })
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'dismissAppNotification', 'puls_app', 'app_notification_reads')
  }

  return mapReadState(data as NotificationReadStateRow)
}

export async function markAllAppNotificationsRead(): Promise<MarkAllNotificationsReadResult> {
  const { data, error } = await pulsApp()
    .rpc('mark_all_app_notifications_read', { p_source_domain: null })
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(
      error,
      'markAllAppNotificationsRead',
      'puls_app',
      'app_notification_reads',
    )
  }

  const row = data as MarkAllNotificationsReadRow
  return {
    markedCount: row.marked_count ?? 0,
    unreadRemainingCount: row.unread_remaining_count ?? 0,
    readAt: row.read_at,
  }
}
