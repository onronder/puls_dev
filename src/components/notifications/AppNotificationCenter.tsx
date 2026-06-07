import {
  AlertTriangle,
  ArrowLeft,
  Bell,
  Check,
  CheckCircle2,
  ChevronRight,
  Clock3,
  ExternalLink,
  FileDown,
  Inbox,
  Info,
  Loader2,
  MailOpen,
  Radio,
  RefreshCw,
  Trash2,
  X,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { toast } from 'sonner'

import { Button } from '#/components/ui/button'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '#/components/ui/sheet'
import {
  dismissAppNotification,
  fetchAppNotificationPage,
  fetchAppNotificationSummary,
  markAllAppNotificationsRead,
  markAppNotificationRead,
  subscribeToAppNotificationSignals,
  type AppNotification,
  type AppNotificationCursor,
  type AppNotificationRealtimeStatus,
  type AppNotificationSeverity,
  type NotificationCenterFilter,
} from '#/lib/data'
import {
  buildAppNotificationIssueCsv,
  resolveAppNotificationAction,
  type AppNotificationActionTarget,
} from '#/lib/notifications/app-notification-actions'
import { cn } from '#/lib/utils'

const NOTIFICATION_PAGE_SIZE = 20

const filters: NotificationCenterFilter[] = ['all', 'unread', 'action_required']

const safeSummaryFields = [
  'source_event_key',
  'safe_error_code',
  'job_type',
  'job_status',
  'failure_class',
  'operator_severity',
  'operation',
  'entity_type',
  'target_table',
  'row_count',
  'rollback_count',
  'blocked_count',
  'field_diff_count',
  'rollback_snapshot_count',
  'next_action_key',
  'canonical_write',
  'rollback_execution',
  'source_writeback',
  'provider_api_calls',
  'credential_readback',
  'raw_payload_readback',
  'field_value_readback',
  'snapshot_payload_readback',
  'external_delivery_enabled',
  'notification_realtime_enabled',
]

function severityTone(severity: AppNotificationSeverity) {
  switch (severity) {
    case 'critical':
    case 'error':
      return {
        icon: AlertTriangle,
        className: 'bg-[var(--color-danger-soft)] text-[var(--color-danger)]',
      }
    case 'warning':
      return {
        icon: AlertTriangle,
        className: 'bg-[var(--color-warning-soft)] text-[var(--color-warning)]',
      }
    case 'success':
      return {
        icon: CheckCircle2,
        className: 'bg-[var(--color-success-soft)] text-[var(--color-success)]',
      }
    default:
      return {
        icon: Info,
        className: 'bg-[var(--color-info-soft)] text-[var(--color-info)]',
      }
  }
}

function compactCount(count: number) {
  if (count > 99) return '99+'
  return String(count)
}

function fallbackTitle(sourceEventKey: string) {
  return sourceEventKey
    .split('_')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
}

function formatRelativeTime(value: string, locale: string) {
  const occurredAt = new Date(value)
  const diffMs = occurredAt.getTime() - Date.now()
  const absMs = Math.abs(diffMs)
  const formatter = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' })

  if (absMs < 60_000) return formatter.format(Math.round(diffMs / 1_000), 'second')
  if (absMs < 3_600_000) return formatter.format(Math.round(diffMs / 60_000), 'minute')
  if (absMs < 86_400_000) return formatter.format(Math.round(diffMs / 3_600_000), 'hour')
  return formatter.format(Math.round(diffMs / 86_400_000), 'day')
}

function formatExactTime(value: string, locale: string) {
  return new Intl.DateTimeFormat(locale, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

function formatSafeValue(value: unknown) {
  if (typeof value === 'boolean') return value ? 'true' : 'false'
  if (typeof value === 'number') return String(value)
  if (typeof value === 'string') return value
  if (value === null || value === undefined) return ''
  if (Array.isArray(value)) return value.join(', ')
  return JSON.stringify(value)
}

type NotificationItemProps = {
  notification: AppNotification
  selected: boolean
  onSelect: (notification: AppNotification) => void
}

function NotificationItem({ notification, selected, onSelect }: NotificationItemProps) {
  const { t, i18n } = useTranslation()
  const tone = severityTone(notification.severity)
  const Icon = tone.icon
  const title = t(notification.titleKey, {
    defaultValue: fallbackTitle(notification.sourceEventKey),
  })
  const body = notification.bodyKey
    ? t(notification.bodyKey, {
        defaultValue: '',
      })
    : ''

  return (
    <button
      type="button"
      aria-current={selected ? 'true' : undefined}
      className={cn(
        'group flex w-full min-w-0 items-start gap-3 border-b border-[var(--color-border)] px-4 py-3 text-left transition-colors last:border-b-0 hover:bg-[var(--color-bg-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)] focus-visible:ring-inset',
        selected && 'bg-[var(--color-bg-elevated)]',
      )}
      onClick={() => onSelect(notification)}
    >
      <span
        className={cn(
          'mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg',
          tone.className,
        )}
      >
        <Icon className="h-4 w-4" aria-hidden="true" />
      </span>
      <span className="min-w-0 flex-1">
        <span className="flex min-w-0 items-start gap-2">
          <span
            className={cn(
              'min-w-0 flex-1 text-sm font-semibold leading-snug text-[var(--color-text-primary)]',
              notification.isRead && 'font-medium text-[var(--color-text-secondary)]',
            )}
          >
            {title}
          </span>
          {!notification.isRead ? (
            <span
              className="mt-1 h-2 w-2 shrink-0 rounded-full bg-[var(--color-primary)]"
              aria-label={t('notifications.center.unread')}
            />
          ) : null}
        </span>
        {body ? (
          <span className="mt-1 line-clamp-2 block text-xs leading-5 text-[var(--color-text-muted)]">
            {body}
          </span>
        ) : null}
        <span className="mt-2 flex flex-wrap items-center gap-2 text-[11px] font-medium text-[var(--color-text-muted)]">
          <span>
            {t(`notifications.source.${notification.sourceDomain}`, {
              defaultValue: notification.sourceDomain,
            })}
          </span>
          <span aria-hidden="true">•</span>
          <span>{formatRelativeTime(notification.occurredAt, i18n.language)}</span>
          {notification.isActionRequired ? (
            <span className="rounded-full border border-[color-mix(in_srgb,var(--color-warning)_28%,transparent)] bg-[var(--color-warning-soft)] px-2 py-0.5 text-[var(--color-warning)]">
              {t('notifications.center.actionRequired')}
            </span>
          ) : null}
        </span>
      </span>
      <ChevronRight
        className="mt-2 h-4 w-4 shrink-0 text-[var(--color-text-muted)] transition-transform group-hover:translate-x-0.5"
        aria-hidden="true"
      />
    </button>
  )
}

type NotificationDetailProps = {
  notification: AppNotification
  onBack: () => void
  onDismiss: (notificationId: string) => void
  onNavigate: (target: AppNotificationActionTarget) => void
  onExportIssue: (notification: AppNotification, copy: AppNotificationIssueCsvCopy) => void
  dismissing: boolean
}

type AppNotificationIssueCsvCopy = {
  title: string
  body: string
  severity: string
  source: string
  status: string
  received: string
}

function NotificationDetail({
  notification,
  onBack,
  onDismiss,
  onNavigate,
  onExportIssue,
  dismissing,
}: NotificationDetailProps) {
  const { t, i18n } = useTranslation()
  const tone = severityTone(notification.severity)
  const Icon = tone.icon
  const title = t(notification.titleKey, {
    defaultValue: fallbackTitle(notification.sourceEventKey),
  })
  const body = notification.bodyKey
    ? t(notification.bodyKey, {
        defaultValue: '',
      })
    : ''
  const summaryRows = safeSummaryFields
    .map((field) => ({
      field,
      value: notification.safeSummary[field],
    }))
    .filter(
      (row) => row.value !== undefined && row.value !== null && formatSafeValue(row.value) !== '',
    )
    .slice(0, 10)
  const action = resolveAppNotificationAction(notification)
  const primaryAction = action.primaryAction
  const sourceLabel = t(`notifications.source.${notification.sourceDomain}`, {
    defaultValue: notification.sourceDomain,
  })
  const statusLabel = notification.isRead
    ? t('notifications.center.read')
    : t('notifications.center.unread')
  const severityLabel = t(`notifications.severity.${notification.severity}`)
  const receivedLabel = formatRelativeTime(notification.occurredAt, i18n.language)
  const csvCopy = {
    title,
    body,
    severity: severityLabel,
    source: sourceLabel,
    status: statusLabel,
    received: receivedLabel,
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex items-center gap-2 border-b border-[var(--color-border)] px-4 py-3">
        <Button
          type="button"
          variant="ghost"
          size="icon"
          onClick={onBack}
          aria-label={t('notifications.center.backToList')}
        >
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-[var(--color-text-primary)]">
            {t('notifications.center.detail')}
          </p>
          <p className="truncate text-xs text-[var(--color-text-muted)]">
            {formatExactTime(notification.occurredAt, i18n.language)}
          </p>
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4">
        <div className="flex items-start gap-3">
          <span
            className={cn(
              'flex h-10 w-10 shrink-0 items-center justify-center rounded-lg',
              tone.className,
            )}
          >
            <Icon className="h-5 w-5" aria-hidden="true" />
          </span>
          <div className="min-w-0 flex-1">
            <h3 className="text-base font-semibold leading-snug text-[var(--color-text-primary)]">
              {title}
            </h3>
            {body ? (
              <p className="mt-2 text-sm leading-6 text-[var(--color-text-secondary)]">{body}</p>
            ) : null}
          </div>
        </div>

        <dl className="mt-5 grid grid-cols-1 gap-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-3 text-xs sm:grid-cols-2">
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('notifications.center.severity')}</dt>
            <dd className="mt-1 font-semibold text-[var(--color-text-primary)]">
              {severityLabel}
            </dd>
          </div>
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('notifications.center.source')}</dt>
            <dd className="mt-1 font-semibold text-[var(--color-text-primary)]">
              {sourceLabel}
            </dd>
          </div>
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('notifications.center.status')}</dt>
            <dd className="mt-1 font-semibold text-[var(--color-text-primary)]">
              {statusLabel}
            </dd>
          </div>
          <div>
            <dt className="text-[var(--color-text-muted)]">{t('notifications.center.received')}</dt>
            <dd className="mt-1 font-semibold text-[var(--color-text-primary)]">
              {receivedLabel}
            </dd>
          </div>
        </dl>

        <div className="mt-5">
          <h4 className="text-sm font-semibold text-[var(--color-text-primary)]">
            {t('notifications.center.safeSummary')}
          </h4>
          {summaryRows.length ? (
            <dl className="mt-2 divide-y divide-[var(--color-border)] rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)]">
              {summaryRows.map((row) => (
                <div
                  key={row.field}
                  className="grid gap-1 px-3 py-2 text-xs sm:grid-cols-[150px_1fr]"
                >
                  <dt className="font-medium text-[var(--color-text-muted)]">
                    {t(`notifications.safeSummary.${row.field}`, row.field)}
                  </dt>
                  <dd className="break-all text-[var(--color-text-secondary)]">
                    {formatSafeValue(row.value)}
                  </dd>
                </div>
              ))}
            </dl>
          ) : (
            <p className="mt-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-3 text-sm text-[var(--color-text-muted)]">
              {t('notifications.center.noSafeSummary')}
            </p>
          )}
        </div>
      </div>

      <div className="flex flex-col gap-2 border-t border-[var(--color-border)] px-4 py-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))] sm:flex-row">
        {primaryAction ? (
          <Button
            type="button"
            className="sm:flex-1"
            onClick={() => onNavigate(primaryAction.target)}
          >
            <ExternalLink className="h-4 w-4" />
            {t(primaryAction.labelKey)}
          </Button>
        ) : null}
        {action.canExportIssueCsv ? (
          <Button
            type="button"
            variant={primaryAction ? 'outline' : 'default'}
            className="sm:flex-1"
            onClick={() => onExportIssue(notification, csvCopy)}
          >
            <FileDown className="h-4 w-4" />
            {t('notifications.center.exportIssueCsv')}
          </Button>
        ) : null}
        <Button
          type="button"
          variant="outline"
          className="sm:flex-1"
          onClick={() => onDismiss(notification.notificationId)}
          disabled={dismissing}
        >
          {dismissing ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Trash2 className="h-4 w-4" />
          )}
          {t('notifications.center.dismiss')}
        </Button>
      </div>
    </div>
  )
}

export function AppNotificationCenter() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [open, setOpen] = useState(false)
  const [filter, setFilter] = useState<NotificationCenterFilter>('all')
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [realtimeStatus, setRealtimeStatus] = useState<AppNotificationRealtimeStatus>('disabled')

  const summaryQuery = useQuery({
    queryKey: ['app-notifications', 'summary'],
    queryFn: fetchAppNotificationSummary,
    refetchInterval: (query) => (query.state.data?.notificationRealtimeEnabled ? 60_000 : 30_000),
    staleTime: 30_000,
  })

  const pageQuery = useInfiniteQuery({
    queryKey: ['app-notifications', 'page', filter],
    queryFn: ({ pageParam }) =>
      fetchAppNotificationPage({
        filter,
        cursor: pageParam as AppNotificationCursor | null,
        limit: NOTIFICATION_PAGE_SIZE,
      }),
    initialPageParam: null as AppNotificationCursor | null,
    getNextPageParam: (page) => (page.hasMore ? page.nextCursor : undefined),
    enabled: open,
  })

  const notifications = useMemo(
    () => pageQuery.data?.pages.flatMap((page) => page.items) ?? [],
    [pageQuery.data],
  )
  const selectedNotification = notifications.find(
    (notification) => notification.notificationId === selectedId,
  )
  const summary = summaryQuery.data
  const unreadCount = summary?.unreadCount ?? 0
  const actionRequiredCount = summary?.actionRequiredCount ?? 0
  const criticalCount = summary?.criticalCount ?? 0

  const invalidateNotifications = useCallback(async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['app-notifications', 'summary'] }),
      queryClient.invalidateQueries({ queryKey: ['app-notifications', 'page'] }),
    ])
  }, [queryClient])

  useEffect(() => {
    const subscription = subscribeToAppNotificationSignals({
      tenantId: summary?.tenantId ?? null,
      enabled: summary?.notificationRealtimeEnabled ?? false,
      onSignal: () => void invalidateNotifications(),
      onStatusChange: setRealtimeStatus,
    })

    return subscription.unsubscribe
  }, [invalidateNotifications, summary?.notificationRealtimeEnabled, summary?.tenantId])

  const markReadMutation = useMutation({
    mutationFn: markAppNotificationRead,
    onSuccess: () => void invalidateNotifications(),
  })

  const markAllReadMutation = useMutation({
    mutationFn: markAllAppNotificationsRead,
    onSuccess: async () => {
      await invalidateNotifications()
      toast.success(t('notifications.center.markAllReadSuccess'))
    },
    onError: () => {
      toast.error(t('notifications.center.actionFailed'))
    },
  })

  const dismissMutation = useMutation({
    mutationFn: dismissAppNotification,
    onSuccess: async () => {
      setSelectedId(null)
      await invalidateNotifications()
      toast.success(t('notifications.center.dismissSuccess'))
    },
    onError: () => {
      toast.error(t('notifications.center.actionFailed'))
    },
  })

  const handleSelect = (notification: AppNotification) => {
    setSelectedId(notification.notificationId)
    if (!notification.isRead) {
      markReadMutation.mutate(notification.notificationId)
    }
  }

  const handleOpenChange = (nextOpen: boolean) => {
    if (!nextOpen) setSelectedId(null)
    setOpen(nextOpen)
  }

  const handleFilterChange = (nextFilter: NotificationCenterFilter) => {
    setSelectedId(null)
    setFilter(nextFilter)
  }

  const handleNavigate = (target: AppNotificationActionTarget) => {
    handleOpenChange(false)
    if (target.to === '/erp') {
      void navigate({ to: '/erp', search: target.search })
      return
    }
    void navigate({ to: '/dashboard' })
  }

  const handleExportIssue = (
    notification: AppNotification,
    copy: AppNotificationIssueCsvCopy,
  ) => {
    try {
      const action = resolveAppNotificationAction(notification)
      const csv = buildAppNotificationIssueCsv(notification, copy)
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = action.exportFileName
      document.body.appendChild(link)
      link.click()
      link.remove()
      URL.revokeObjectURL(url)
      toast.success(t('notifications.center.exportIssueSuccess'))
    } catch {
      toast.error(t('notifications.center.exportIssueFailed'))
    }
  }

  const handleRefresh = () => {
    void invalidateNotifications()
  }

  const realtimeLabelKey = summary?.notificationRealtimeEnabled
    ? realtimeStatus === 'connected'
      ? 'notifications.center.realtime.connected'
      : realtimeStatus === 'connecting'
        ? 'notifications.center.realtime.connecting'
        : 'notifications.center.realtime.fallback'
    : 'notifications.center.realtime.polling'

  const realtimeTone =
    summary?.notificationRealtimeEnabled && realtimeStatus === 'connected'
      ? 'text-[var(--color-success)]'
      : 'text-[var(--color-text-muted)]'

  const badgeTone =
    unreadCount > 0 && criticalCount > 0
      ? 'bg-[var(--color-danger)] text-[var(--color-primary-foreground)]'
      : unreadCount > 0 && actionRequiredCount > 0
        ? 'bg-[var(--color-warning)] text-[var(--color-primary-foreground)]'
        : 'bg-[var(--color-primary)] text-[var(--color-primary-foreground)]'

  return (
    <>
      <Button
        type="button"
        variant="ghost"
        size="icon"
        className="relative"
        aria-label={t('notifications.center.bellLabel', {
          unread: unreadCount,
          actionRequired: actionRequiredCount,
        })}
        onClick={() => setOpen(true)}
      >
        <Bell className="h-4 w-4" />
        {unreadCount > 0 ? (
          <span
            className={cn(
              'absolute -right-0.5 -top-0.5 flex min-h-5 min-w-5 items-center justify-center rounded-full px-1 text-[10px] font-bold tabular-nums shadow-lg',
              badgeTone,
            )}
          >
            {compactCount(unreadCount)}
          </span>
        ) : null}
      </Button>

      <Sheet open={open} onOpenChange={handleOpenChange}>
        <SheetContent className="left-auto right-0 top-0 mt-0 h-[100dvh] max-h-[100dvh] w-full rounded-none border-y-0 border-r-0 pb-0 pt-[env(safe-area-inset-top)] sm:max-w-[440px] sm:rounded-none [&>div:first-child]:hidden">
          <SheetHeader className="px-4 py-3">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <SheetTitle>{t('notifications.center.title')}</SheetTitle>
                <SheetDescription>
                  {t('notifications.center.description', {
                    unread: unreadCount,
                    actionRequired: actionRequiredCount,
                  })}
                </SheetDescription>
              </div>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                onClick={() => handleOpenChange(false)}
                aria-label={t('common.close')}
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          </SheetHeader>

          {selectedNotification ? (
            <NotificationDetail
              notification={selectedNotification}
              onBack={() => setSelectedId(null)}
              onDismiss={(notificationId) => dismissMutation.mutate(notificationId)}
              onNavigate={handleNavigate}
              onExportIssue={handleExportIssue}
              dismissing={dismissMutation.isPending}
            />
          ) : (
            <div className="flex min-h-0 flex-1 flex-col">
              <div className="border-b border-[var(--color-border)] px-4 py-3">
                <div className="grid grid-cols-3 gap-2">
                  {filters.map((option) => (
                    <button
                      key={option}
                      type="button"
                      className={cn(
                        'min-h-10 rounded-lg border px-2 text-xs font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)]',
                        option === filter
                          ? 'border-[var(--color-border-strong)] bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
                          : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-bg-elevated)]',
                      )}
                      onClick={() => handleFilterChange(option)}
                    >
                      {t(`notifications.center.filters.${option}`)}
                    </button>
                  ))}
                </div>

                <div className="mt-3 flex items-center gap-2">
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => markAllReadMutation.mutate()}
                    disabled={unreadCount === 0 || markAllReadMutation.isPending}
                  >
                    {markAllReadMutation.isPending ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <MailOpen className="h-4 w-4" />
                    )}
                    {t('notifications.center.markAllRead')}
                  </Button>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    onClick={handleRefresh}
                    aria-label={t('notifications.center.refresh')}
                    disabled={summaryQuery.isFetching || pageQuery.isFetching}
                  >
                    <RefreshCw
                      className={cn(
                        'h-4 w-4',
                        (summaryQuery.isFetching || pageQuery.isFetching) && 'animate-spin',
                      )}
                    />
                  </Button>
                </div>

                <div className={cn('mt-2 flex items-center gap-2 text-xs', realtimeTone)}>
                  {summary?.notificationRealtimeEnabled && realtimeStatus === 'connected' ? (
                    <Radio className="h-3.5 w-3.5" />
                  ) : (
                    <RefreshCw className="h-3.5 w-3.5" />
                  )}
                  <span>{t(realtimeLabelKey)}</span>
                </div>
              </div>

              <div aria-live="polite" className="sr-only">
                {t('notifications.center.liveRegion', { unread: unreadCount })}
              </div>

              <div className="min-h-0 flex-1 overflow-y-auto">
                {pageQuery.isLoading ? (
                  <div className="space-y-3 px-4 py-4">
                    {Array.from({ length: 5 }).map((_, index) => (
                      <div
                        key={index}
                        className="h-20 animate-pulse rounded-lg bg-[var(--color-bg-elevated)]"
                      />
                    ))}
                  </div>
                ) : pageQuery.isError || summaryQuery.isError ? (
                  <div className="flex min-h-[320px] flex-col items-center justify-center px-6 text-center">
                    <AlertTriangle className="h-8 w-8 text-[var(--color-warning)]" />
                    <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">
                      {t('notifications.center.errorTitle')}
                    </p>
                    <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                      {t('notifications.center.errorDescription')}
                    </p>
                    <Button type="button" className="mt-4" onClick={handleRefresh}>
                      <RefreshCw className="h-4 w-4" />
                      {t('common.retry')}
                    </Button>
                  </div>
                ) : notifications.length === 0 ? (
                  <div className="flex min-h-[320px] flex-col items-center justify-center px-6 text-center">
                    <Inbox className="h-9 w-9 text-[var(--color-text-muted)]" />
                    <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">
                      {t('notifications.center.emptyTitle')}
                    </p>
                    <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                      {t('notifications.center.emptyDescription')}
                    </p>
                  </div>
                ) : (
                  <div>
                    {notifications.map((notification) => (
                      <NotificationItem
                        key={notification.notificationId}
                        notification={notification}
                        selected={notification.notificationId === selectedId}
                        onSelect={handleSelect}
                      />
                    ))}
                    {pageQuery.hasNextPage ? (
                      <div className="px-4 py-4">
                        <Button
                          type="button"
                          variant="outline"
                          className="w-full"
                          disabled={pageQuery.isFetchingNextPage}
                          onClick={() => void pageQuery.fetchNextPage()}
                        >
                          {pageQuery.isFetchingNextPage ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <Clock3 className="h-4 w-4" />
                          )}
                          {t('notifications.center.loadMore')}
                        </Button>
                      </div>
                    ) : (
                      <div className="flex items-center justify-center gap-2 px-4 py-4 text-xs text-[var(--color-text-muted)]">
                        <Check className="h-4 w-4" />
                        {t('notifications.center.endOfList')}
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}
        </SheetContent>
      </Sheet>
    </>
  )
}
