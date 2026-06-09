import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { AlertTriangle, Bell, BellOff, Loader2, RotateCcw, Save, ShieldCheck } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '#/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '#/components/ui/select'
import {
  clearAppNotificationPreference,
  fetchAppNotificationPreferences,
  upsertAppNotificationPreference,
  type AppNotificationPreference,
  type AppNotificationPreferenceInput,
  type AppNotificationSeverity,
} from '#/lib/data'
import { cn } from '#/lib/utils'

const preferenceScopes = [
  {
    sourceDomain: 'puls_workflow',
    sourceEventKey: 'all',
    labelKey: 'notifications.preferences.scopes.workflow.title',
    descriptionKey: 'notifications.preferences.scopes.workflow.description',
  },
  {
    sourceDomain: 'connector_runtime',
    sourceEventKey: 'all',
    labelKey: 'notifications.preferences.scopes.connectorRuntime.title',
    descriptionKey: 'notifications.preferences.scopes.connectorRuntime.description',
  },
] as const

const preferenceSeverityOptions: AppNotificationSeverity[] = [
  'info',
  'success',
  'warning',
  'error',
  'critical',
]

type NotificationMuteMode = 'none' | 'one_hour' | 'one_day' | 'existing'
type NotificationPreferenceScope = (typeof preferenceScopes)[number]

type NotificationPreferenceDraft = {
  inboxEnabled: boolean
  minimumSeverity: AppNotificationSeverity
  actionRequiredOnly: boolean
  muteMode: NotificationMuteMode
}

type NotificationPreferenceSettingsPanelProps = {
  userId: string | null | undefined
}

const defaultPreferenceDraft: NotificationPreferenceDraft = {
  inboxEnabled: true,
  minimumSeverity: 'info',
  actionRequiredOnly: false,
  muteMode: 'none',
}

function isFutureTimestamp(value: string | null) {
  return Boolean(value && new Date(value).getTime() > Date.now())
}

function draftFromPreference(
  preference: AppNotificationPreference | null,
): NotificationPreferenceDraft {
  if (!preference) return defaultPreferenceDraft

  return {
    inboxEnabled: preference.inboxEnabled,
    minimumSeverity: preference.minimumSeverity,
    actionRequiredOnly: preference.actionRequiredOnly,
    muteMode: isFutureTimestamp(preference.mutedUntil) ? 'existing' : 'none',
  }
}

function mutedUntilForMode(
  mode: NotificationMuteMode,
  existingPreference: AppNotificationPreference | null,
) {
  if (mode === 'one_hour') return new Date(Date.now() + 3_600_000).toISOString()
  if (mode === 'one_day') return new Date(Date.now() + 86_400_000).toISOString()
  if (mode === 'existing') return existingPreference?.mutedUntil ?? null
  return null
}

function formatExactTime(value: string, locale: string) {
  return new Intl.DateTimeFormat(locale, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

export function NotificationPreferenceSettingsPanel({
  userId,
}: NotificationPreferenceSettingsPanelProps) {
  const { t, i18n } = useTranslation()
  const queryClient = useQueryClient()
  const [scope, setScope] = useState<NotificationPreferenceScope>(preferenceScopes[0])
  const [preferenceDraft, setPreferenceDraft] = useState<NotificationPreferenceDraft | null>(null)

  const preferencesQuery = useQuery({
    queryKey: ['app-notifications', 'preferences', scope.sourceDomain],
    queryFn: () => fetchAppNotificationPreferences(scope.sourceDomain),
    enabled: Boolean(userId),
    staleTime: 30_000,
  })

  const activePreference = useMemo(
    () =>
      preferencesQuery.data?.find(
        (preference) =>
          preference.sourceDomain === scope.sourceDomain &&
          preference.sourceEventKey === scope.sourceEventKey,
      ) ?? null,
    [preferencesQuery.data, scope.sourceDomain, scope.sourceEventKey],
  )

  const draft = preferenceDraft ?? draftFromPreference(activePreference)
  const existingMuteActive =
    draft.muteMode === 'existing' && isFutureTimestamp(activePreference?.mutedUntil ?? null)
  const muteOptions: NotificationMuteMode[] = existingMuteActive
    ? ['existing', 'none', 'one_hour', 'one_day']
    : ['none', 'one_hour', 'one_day']
  const activeMuteLabel =
    existingMuteActive && activePreference?.mutedUntil
      ? t('notifications.preferences.mute.existing', {
          time: formatExactTime(activePreference.mutedUntil, i18n.language),
        })
      : null

  const invalidateNotificationPreferences = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['app-notifications', 'preferences'] }),
      queryClient.invalidateQueries({ queryKey: ['app-notifications', 'summary'] }),
      queryClient.invalidateQueries({ queryKey: ['app-notifications', 'page'] }),
      userId
        ? queryClient.invalidateQueries({ queryKey: ['settings-overview', userId] })
        : Promise.resolve(),
    ])
  }

  const upsertPreferenceMutation = useMutation({
    mutationFn: (input: AppNotificationPreferenceInput) => upsertAppNotificationPreference(input),
    onSuccess: async () => {
      setPreferenceDraft(null)
      await invalidateNotificationPreferences()
      toast.success(t('notifications.preferences.saveSuccess'))
    },
    onError: () => {
      toast.error(t('notifications.center.actionFailed'))
    },
  })

  const clearPreferenceMutation = useMutation({
    mutationFn: () => clearAppNotificationPreference(scope.sourceDomain, scope.sourceEventKey),
    onSuccess: async () => {
      setPreferenceDraft(null)
      await invalidateNotificationPreferences()
      toast.success(t('notifications.preferences.resetSuccess'))
    },
    onError: () => {
      toast.error(t('notifications.center.actionFailed'))
    },
  })

  const updateDraft = (patch: Partial<NotificationPreferenceDraft>) => {
    setPreferenceDraft({ ...draft, ...patch })
  }

  const selectScope = (nextScope: NotificationPreferenceScope) => {
    setScope(nextScope)
    setPreferenceDraft(null)
  }

  const savePreference = () => {
    upsertPreferenceMutation.mutate({
      sourceDomain: scope.sourceDomain,
      sourceEventKey: scope.sourceEventKey,
      inboxEnabled: draft.inboxEnabled,
      minimumSeverity: draft.minimumSeverity,
      mutedUntil: mutedUntilForMode(draft.muteMode, activePreference),
      actionRequiredOnly: draft.actionRequiredOnly,
    })
  }

  const isBusy = upsertPreferenceMutation.isPending || clearPreferenceMutation.isPending
  const controlsDisabled =
    !userId || preferencesQuery.isLoading || preferencesQuery.isError || isBusy

  return (
    <div className="space-y-4">
      <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-4">
        <div className="flex items-start gap-3">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
            <Bell className="h-[18px] w-[18px]" aria-hidden="true" />
          </span>
          <div className="min-w-0">
            <p className="text-sm font-semibold text-[var(--color-text-primary)]">
              {t('notifications.preferences.title')}
            </p>
            <p className="mt-1 text-sm leading-6 text-[var(--color-text-muted)]">
              {t('notifications.preferences.description')}
            </p>
          </div>
        </div>
      </div>

      <section className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
          {t('notifications.preferences.sourceScope')}
        </p>
        <div className="grid gap-2 sm:grid-cols-2">
          {preferenceScopes.map((candidate) => {
            const selected =
              candidate.sourceDomain === scope.sourceDomain &&
              candidate.sourceEventKey === scope.sourceEventKey

            return (
              <button
                key={`${candidate.sourceDomain}:${candidate.sourceEventKey}`}
                type="button"
                aria-pressed={selected}
                className={cn(
                  'rounded-lg border p-3 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)]',
                  selected
                    ? 'border-[var(--color-border-strong)] bg-[var(--color-primary-soft)]'
                    : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] hover:border-[var(--color-border-strong)]',
                )}
                onClick={() => selectScope(candidate)}
              >
                <span className="block text-sm font-semibold text-[var(--color-text-primary)]">
                  {t(candidate.labelKey)}
                </span>
                <span className="mt-1 block text-xs leading-5 text-[var(--color-text-muted)]">
                  {t(candidate.descriptionKey)}
                </span>
              </button>
            )
          })}
        </div>
      </section>

      {preferencesQuery.isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, index) => (
            <div
              key={index}
              className="h-20 animate-pulse rounded-xl bg-[var(--color-bg-elevated)]"
            />
          ))}
        </div>
      ) : preferencesQuery.isError ? (
        <div className="rounded-xl border border-[var(--color-warning)] bg-[var(--color-warning-soft)] p-4">
          <div className="flex items-start gap-3">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-warning)]" />
            <div className="min-w-0">
              <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                {t('notifications.preferences.errorTitle')}
              </p>
              <p className="mt-1 text-sm leading-6 text-[var(--color-text-muted)]">
                {t('notifications.preferences.errorDescription')}
              </p>
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="mt-3"
                onClick={() => preferencesQuery.refetch()}
              >
                {t('common.retry')}
              </Button>
            </div>
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          <section className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                  {t('notifications.preferences.inbox.title')}
                </p>
                <p className="mt-1 text-xs leading-5 text-[var(--color-text-muted)]">
                  {t('notifications.preferences.inbox.description')}
                </p>
              </div>
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]">
                {draft.inboxEnabled ? (
                  <Bell className="h-4 w-4" aria-hidden="true" />
                ) : (
                  <BellOff className="h-4 w-4" aria-hidden="true" />
                )}
              </span>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-2">
              <button
                type="button"
                aria-pressed={draft.inboxEnabled}
                className={cn(
                  'min-h-11 rounded-lg border px-3 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)]',
                  draft.inboxEnabled
                    ? 'border-[var(--color-border-strong)] bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
                    : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)]',
                )}
                onClick={() => updateDraft({ inboxEnabled: true })}
              >
                {t('notifications.preferences.inbox.enabled')}
              </button>
              <button
                type="button"
                aria-pressed={!draft.inboxEnabled}
                className={cn(
                  'min-h-11 rounded-lg border px-3 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)]',
                  !draft.inboxEnabled
                    ? 'border-[color-mix(in_srgb,var(--color-warning)_35%,transparent)] bg-[var(--color-warning-soft)] text-[var(--color-warning)]'
                    : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)]',
                )}
                onClick={() => updateDraft({ inboxEnabled: false })}
              >
                {t('notifications.preferences.inbox.disabled')}
              </button>
            </div>
          </section>

          <section className="grid gap-4 sm:grid-cols-2">
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
              <label
                className="text-sm font-semibold text-[var(--color-text-primary)]"
                htmlFor="settings-notification-minimum-severity"
              >
                {t('notifications.preferences.minimumSeverity.title')}
              </label>
              <p className="mt-1 text-xs leading-5 text-[var(--color-text-muted)]">
                {t('notifications.preferences.minimumSeverity.description')}
              </p>
              <Select
                value={draft.minimumSeverity}
                onValueChange={(value) =>
                  updateDraft({ minimumSeverity: value as AppNotificationSeverity })
                }
                disabled={controlsDisabled}
              >
                <SelectTrigger id="settings-notification-minimum-severity" className="mt-3">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {preferenceSeverityOptions.map((severity) => (
                    <SelectItem key={severity} value={severity}>
                      {t(`notifications.severity.${severity}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
              <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                {t('notifications.preferences.actionOnly.title')}
              </p>
              <p className="mt-1 text-xs leading-5 text-[var(--color-text-muted)]">
                {t('notifications.preferences.actionOnly.description')}
              </p>
              <div className="mt-3 grid grid-cols-2 gap-2">
                <button
                  type="button"
                  aria-pressed={!draft.actionRequiredOnly}
                  className={cn(
                    'min-h-11 rounded-lg border px-3 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)]',
                    !draft.actionRequiredOnly
                      ? 'border-[var(--color-border-strong)] bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
                      : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)]',
                  )}
                  onClick={() => updateDraft({ actionRequiredOnly: false })}
                >
                  {t('notifications.preferences.actionOnly.all')}
                </button>
                <button
                  type="button"
                  aria-pressed={draft.actionRequiredOnly}
                  className={cn(
                    'min-h-11 rounded-lg border px-3 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)]',
                    draft.actionRequiredOnly
                      ? 'border-[var(--color-border-strong)] bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
                      : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)]',
                  )}
                  onClick={() => updateDraft({ actionRequiredOnly: true })}
                >
                  {t('notifications.preferences.actionOnly.actionRequired')}
                </button>
              </div>
            </div>
          </section>

          <section className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
            <p className="text-sm font-semibold text-[var(--color-text-primary)]">
              {t('notifications.preferences.mute.title')}
            </p>
            <p className="mt-1 text-xs leading-5 text-[var(--color-text-muted)]">
              {t('notifications.preferences.mute.description')}
            </p>
            <div className="mt-3 grid gap-2 sm:grid-cols-3">
              {muteOptions.map((mode) => (
                <button
                  key={mode}
                  type="button"
                  aria-pressed={draft.muteMode === mode}
                  className={cn(
                    'min-h-11 rounded-lg border px-3 text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)]',
                    draft.muteMode === mode
                      ? 'border-[color-mix(in_srgb,var(--color-warning)_35%,transparent)] bg-[var(--color-warning-soft)] text-[var(--color-warning)]'
                      : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)]',
                  )}
                  onClick={() => updateDraft({ muteMode: mode })}
                >
                  {mode === 'existing' && activeMuteLabel
                    ? activeMuteLabel
                    : t(`notifications.preferences.mute.${mode}`)}
                </button>
              ))}
            </div>
          </section>

          <div className="flex items-start gap-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-3">
            <ShieldCheck
              className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-success)]"
              aria-hidden="true"
            />
            <p className="text-xs leading-5 text-[var(--color-text-muted)]">
              {t('notifications.preferences.criticalNote')}
            </p>
          </div>

          <div className="flex flex-col gap-2 sm:flex-row">
            <Button
              type="button"
              className="sm:flex-1"
              onClick={savePreference}
              disabled={controlsDisabled}
            >
              {upsertPreferenceMutation.isPending ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Save className="h-4 w-4" />
              )}
              {t('notifications.preferences.save')}
            </Button>
            <Button
              type="button"
              variant="outline"
              className="sm:flex-1"
              onClick={() => clearPreferenceMutation.mutate()}
              disabled={!activePreference || controlsDisabled}
            >
              {clearPreferenceMutation.isPending ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <RotateCcw className="h-4 w-4" />
              )}
              {t('notifications.preferences.reset')}
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
