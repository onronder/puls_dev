import { fetchDemoSettingsOverview } from '#/lib/demo/puls-demo-data'
import {
  pulsAudit,
  pulsCalc,
  pulsIntegration,
  resolveTenantContext,
} from '#/lib/data/client'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type SettingsSectionId =
  | 'accountSecurity'
  | 'tenant'
  | 'notifications'
  | 'locale'
  | 'theme'
  | 'roleAccess'

export type SettingsStateStatus = 'ready' | 'attention' | 'locked'
export type SettingsStateTone = 'success' | 'warning' | 'neutral'

export type SettingsValue = {
  text?: string
  key?: string
  params?: Record<string, string | number | boolean | null>
}

export type SettingsEvidence = {
  labelKey: string
  value: SettingsValue
}

export type SettingsSection = {
  id: SettingsSectionId
  titleKey: string
  summaryKey: string
  actionKey: string
  sheetDescriptionKey: string
  sheetBodyKey: string
  status: SettingsStateStatus
  statusLabelKey: string
  tone: SettingsStateTone
  value: SettingsValue
  helperKey: string
  evidence: SettingsEvidence[]
}

export type SettingsSetupHubItem = {
  to: string
  status: SettingsStateStatus
  statusLabelKey: string
  tone: SettingsStateTone
  value: SettingsValue
  hintKey: string
  progress: number
}

export type SettingsOverview = {
  tenantName: string | null
  employeeName: string | null
  personaRole: string
  auditLogDays: number
  auditLogSensitiveCount: number
  sections: SettingsSection[]
  setupHubItems: SettingsSetupHubItem[]
}

type SetupReadinessRow = {
  core_setup_pct?: number | null
  workflow_setup_pct?: number | null
  integration_setup_pct?: number | null
  performance_setup_pct?: number | null
  overall_readiness_pct?: number | null
}

type ConnectionRow = {
  provider?: string | null
  display_name?: string | null
  is_active?: boolean | null
  is_enabled?: boolean | null
  setup_status?: string | null
  setup_step?: string | null
}

type QueryResult<T> = {
  data?: T | null
  error?: unknown
}

const AUDIT_LOG_DAYS = 30

const SECTION_KEYS: Record<
  SettingsSectionId,
  Pick<
    SettingsSection,
    'id' | 'titleKey' | 'summaryKey' | 'actionKey' | 'sheetDescriptionKey' | 'sheetBodyKey'
  >
> = {
  accountSecurity: {
    id: 'accountSecurity',
    titleKey: 'settingsSetup.sections.accountSecurity.title',
    summaryKey: 'settingsSetup.sections.accountSecurity.summary',
    actionKey: 'settingsSetup.sections.accountSecurity.action',
    sheetDescriptionKey: 'settingsSetup.sections.accountSecurity.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.accountSecurity.sheetBody',
  },
  tenant: {
    id: 'tenant',
    titleKey: 'settingsSetup.sections.tenant.title',
    summaryKey: 'settingsSetup.sections.tenant.summary',
    actionKey: 'settingsSetup.sections.tenant.action',
    sheetDescriptionKey: 'settingsSetup.sections.tenant.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.tenant.sheetBody',
  },
  notifications: {
    id: 'notifications',
    titleKey: 'settingsSetup.sections.notifications.title',
    summaryKey: 'settingsSetup.sections.notifications.summary',
    actionKey: 'settingsSetup.sections.notifications.action',
    sheetDescriptionKey: 'settingsSetup.sections.notifications.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.notifications.sheetBody',
  },
  locale: {
    id: 'locale',
    titleKey: 'settingsSetup.sections.locale.title',
    summaryKey: 'settingsSetup.sections.locale.summary',
    actionKey: 'settingsSetup.sections.locale.action',
    sheetDescriptionKey: 'settingsSetup.sections.locale.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.locale.sheetBody',
  },
  theme: {
    id: 'theme',
    titleKey: 'settingsSetup.sections.theme.title',
    summaryKey: 'settingsSetup.sections.theme.summary',
    actionKey: 'settingsSetup.sections.theme.action',
    sheetDescriptionKey: 'settingsSetup.sections.theme.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.theme.sheetBody',
  },
  roleAccess: {
    id: 'roleAccess',
    titleKey: 'settingsSetup.sections.roleAccess.title',
    summaryKey: 'settingsSetup.sections.roleAccess.summary',
    actionKey: 'settingsSetup.sections.roleAccess.action',
    sheetDescriptionKey: 'settingsSetup.sections.roleAccess.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.roleAccess.sheetBody',
  },
}

function value(text: string): SettingsValue {
  return { text }
}

function valueKey(key: string, params?: SettingsValue['params']): SettingsValue {
  return { key, params }
}

function state(status: SettingsStateStatus): Pick<SettingsSection, 'statusLabelKey' | 'tone'> & {
  status: SettingsStateStatus
} {
  switch (status) {
    case 'ready':
      return {
        status,
        statusLabelKey: 'settingsSetup.state.ready',
        tone: 'success',
      }
    case 'attention':
      return {
        status,
        statusLabelKey: 'settingsSetup.state.attention',
        tone: 'warning',
      }
    case 'locked':
      return {
        status,
        statusLabelKey: 'settingsSetup.state.locked',
        tone: 'neutral',
      }
  }
}

function statusFromPct(pct: number): SettingsStateStatus {
  if (pct >= 100) return 'ready'
  if (pct > 0) return 'attention'
  return 'locked'
}

function pct(input: number | null | undefined): number {
  if (typeof input !== 'number' || Number.isNaN(input)) return 0
  return Math.max(0, Math.min(100, Math.round(input)))
}

async function safeSingle<T>(query: PromiseLike<QueryResult<T>>): Promise<T | null> {
  const result = await query
  if (result.error) return null
  return result.data ?? null
}

async function safeCount(query: PromiseLike<{ count?: number | null; error?: unknown }>) {
  const result = await query
  if (result.error) return 0
  return result.count ?? 0
}

function auditSince(): string {
  const since = new Date()
  since.setDate(since.getDate() - AUDIT_LOG_DAYS)
  return since.toISOString()
}

function connectorStateValue(connection: ConnectionRow | null): SettingsValue {
  if (!connection) return valueKey('settingsSetup.values.noSource')
  if (connection.is_enabled === false || connection.setup_status === 'disabled') {
    return valueKey('settingsSetup.values.disabled')
  }
  if (connection.is_active === true || connection.setup_status === 'connected') {
    return valueKey('settingsSetup.values.connected')
  }
  if (connection.setup_status === 'draft') return valueKey('settingsSetup.values.draft')
  if (connection.setup_status === 'preflight_ready') return valueKey('settingsSetup.values.preflightReady')
  return valueKey('settingsSetup.values.setupInProgress')
}

function section(
  id: SettingsSectionId,
  status: SettingsStateStatus,
  fields: Pick<SettingsSection, 'value' | 'helperKey' | 'evidence'>,
): SettingsSection {
  return {
    ...SECTION_KEYS[id],
    ...state(status),
    ...fields,
  }
}

function setupHubItem({
  to,
  progress,
  value: itemValue,
  hintKey,
}: {
  to: string
  progress: number
  value?: SettingsValue
  hintKey?: string
}): SettingsSetupHubItem {
  const status = statusFromPct(progress)
  return {
    to,
    ...state(status),
    value: itemValue ?? valueKey('settingsSetup.values.percent', { value: progress }),
    hintKey:
      hintKey ??
      (status === 'ready'
        ? 'settingsSetup.setupHub.hints.ready'
        : status === 'attention'
          ? 'settingsSetup.setupHub.hints.attention'
          : 'settingsSetup.setupHub.hints.locked'),
    progress,
  }
}

function emptySettingsOverview(): SettingsOverview {
  const noTenant = valueKey('settingsSetup.values.noTenant')
  return {
    tenantName: null,
    employeeName: null,
    personaRole: 'employee',
    auditLogDays: AUDIT_LOG_DAYS,
    auditLogSensitiveCount: 0,
    sections: [
      section('accountSecurity', 'locked', {
        value: noTenant,
        helperKey: 'settingsSetup.helpers.accountNoTenant',
        evidence: [
          { labelKey: 'settingsSetup.evidence.account', value: noTenant },
          { labelKey: 'settingsSetup.evidence.employee', value: valueKey('settingsSetup.values.notLinked') },
        ],
      }),
      section('tenant', 'locked', {
        value: noTenant,
        helperKey: 'settingsSetup.helpers.tenantMissing',
        evidence: [{ labelKey: 'settingsSetup.evidence.tenant', value: noTenant }],
      }),
      section('notifications', 'locked', {
        value: valueKey('settingsSetup.values.noTenant'),
        helperKey: 'settingsSetup.helpers.notificationsNoTenant',
        evidence: [{ labelKey: 'settingsSetup.evidence.scope', value: noTenant }],
      }),
      section('locale', 'ready', {
        value: valueKey('settingsSetup.values.localeDefault'),
        helperKey: 'settingsSetup.helpers.localeReady',
        evidence: [{ labelKey: 'settingsSetup.evidence.locale', value: valueKey('settingsSetup.values.localeDefault') }],
      }),
      section('theme', 'locked', {
        value: valueKey('settingsSetup.values.themeDefault'),
        helperKey: 'settingsSetup.helpers.themePending',
        evidence: [{ labelKey: 'settingsSetup.evidence.theme', value: valueKey('settingsSetup.values.themeDefault') }],
      }),
      section('roleAccess', 'locked', {
        value: valueKey('settingsSetup.values.noTenant'),
        helperKey: 'settingsSetup.helpers.roleNoTenant',
        evidence: [{ labelKey: 'settingsSetup.evidence.role', value: valueKey('settingsSetup.values.noRole') }],
      }),
    ],
    setupHubItems: [
      setupHubItem({ to: '/erp', progress: 0 }),
      setupHubItem({ to: '/sirket-kurulum', progress: 0 }),
      setupHubItem({ to: '/departmanlar', progress: 0 }),
      setupHubItem({ to: '/pozisyonlar', progress: 0 }),
      setupHubItem({ to: '/izin-tanimlari', progress: 0 }),
      setupHubItem({ to: '/masraf-kategorileri', progress: 0 }),
      setupHubItem({ to: '/performans-parametreleri', progress: 0 }),
    ],
  }
}

function buildSettingsOverview({
  tenantName,
  employeeName,
  employeeLinked,
  personaRole,
  readiness,
  connection,
  mappingCount,
  namespaceCount,
  auditCount,
}: {
  tenantName: string | null
  employeeName: string | null
  employeeLinked: boolean
  personaRole: string
  readiness: SetupReadinessRow | null
  connection: ConnectionRow | null
  mappingCount: number
  namespaceCount: number
  auditCount: number
}): SettingsOverview {
  const corePct = pct(readiness?.core_setup_pct)
  const workflowPct = pct(readiness?.workflow_setup_pct)
  const integrationPct = pct(readiness?.integration_setup_pct)
  const performancePct = pct(readiness?.performance_setup_pct)
  const overallPct = pct(readiness?.overall_readiness_pct)
  const tenantValue = tenantName ? value(tenantName) : valueKey('settingsSetup.values.noTenant')
  const accountStatus = employeeLinked ? 'ready' : 'attention'
  const roleStatus = personaRole === 'hr_admin' || personaRole === 'superadmin' ? 'ready' : 'attention'
  const connectorValue = connectorStateValue(connection)
  const connectorHint = connection
    ? 'settingsSetup.setupHub.hints.connectorSelected'
    : 'settingsSetup.setupHub.hints.connectorMissing'

  return {
    tenantName,
    employeeName,
    personaRole,
    auditLogDays: AUDIT_LOG_DAYS,
    auditLogSensitiveCount: auditCount,
    sections: [
      section('accountSecurity', accountStatus, {
        value: employeeLinked
          ? value(employeeName ?? '—')
          : valueKey('settingsSetup.values.notLinked'),
        helperKey: employeeLinked
          ? 'settingsSetup.helpers.accountLinked'
          : 'settingsSetup.helpers.accountNeedsEmployee',
        evidence: [
          {
            labelKey: 'settingsSetup.evidence.account',
            value: employeeLinked
              ? valueKey('settingsSetup.values.linked')
              : valueKey('settingsSetup.values.notLinked'),
          },
          {
            labelKey: 'settingsSetup.evidence.employee',
            value: employeeLinked ? value(employeeName ?? '—') : valueKey('settingsSetup.values.noEmployee'),
          },
        ],
      }),
      section('tenant', tenantName ? 'ready' : 'locked', {
        value: tenantValue,
        helperKey: tenantName
          ? 'settingsSetup.helpers.tenantReady'
          : 'settingsSetup.helpers.tenantMissing',
        evidence: [
          { labelKey: 'settingsSetup.evidence.tenant', value: tenantValue },
          { labelKey: 'settingsSetup.evidence.readiness', value: valueKey('settingsSetup.values.percent', { value: overallPct }) },
        ],
      }),
      section('notifications', 'locked', {
        value: valueKey('settingsSetup.values.policyPending'),
        helperKey: 'settingsSetup.helpers.notificationsPending',
        evidence: [
          { labelKey: 'settingsSetup.evidence.scope', value: valueKey('settingsSetup.values.roleBased') },
          { labelKey: 'settingsSetup.evidence.audit', value: valueKey('settingsSetup.values.auditCount', { count: auditCount }) },
        ],
      }),
      section('locale', 'ready', {
        value: valueKey('settingsSetup.values.localeDefault'),
        helperKey: 'settingsSetup.helpers.localeReady',
        evidence: [
          { labelKey: 'settingsSetup.evidence.locale', value: valueKey('settingsSetup.values.localeDefault') },
          { labelKey: 'settingsSetup.evidence.timezone', value: valueKey('settingsSetup.values.timezoneDefault') },
        ],
      }),
      section('theme', 'locked', {
        value: valueKey('settingsSetup.values.themeDefault'),
        helperKey: 'settingsSetup.helpers.themePending',
        evidence: [
          { labelKey: 'settingsSetup.evidence.theme', value: valueKey('settingsSetup.values.themeDefault') },
          { labelKey: 'settingsSetup.evidence.preference', value: valueKey('settingsSetup.values.preferencePending') },
        ],
      }),
      section('roleAccess', roleStatus, {
        value:
          personaRole === 'superadmin'
            ? valueKey('settingsSetup.values.superadmin')
            : personaRole === 'hr_admin'
              ? valueKey('settingsSetup.values.hrAdmin')
              : personaRole === 'manager'
                ? valueKey('settingsSetup.values.manager')
                : valueKey('settingsSetup.values.employee'),
        helperKey:
          personaRole === 'hr_admin' || personaRole === 'superadmin'
            ? 'settingsSetup.helpers.roleAdmin'
            : 'settingsSetup.helpers.roleLimited',
        evidence: [
          { labelKey: 'settingsSetup.evidence.role', value: valueKey(`settingsSetup.values.${personaRole}`, undefined) },
          { labelKey: 'settingsSetup.evidence.setupAccess', value: valueKey(roleStatus === 'ready' ? 'settingsSetup.values.enabled' : 'settingsSetup.values.reviewOnly') },
        ],
      }),
    ],
    setupHubItems: [
      setupHubItem({
        to: '/erp',
        progress: integrationPct,
        value: connectorValue,
        hintKey: connectorHint,
      }),
      setupHubItem({ to: '/sirket-kurulum', progress: overallPct }),
      setupHubItem({ to: '/departmanlar', progress: corePct }),
      setupHubItem({ to: '/pozisyonlar', progress: corePct }),
      setupHubItem({ to: '/izin-tanimlari', progress: workflowPct }),
      setupHubItem({ to: '/masraf-kategorileri', progress: workflowPct }),
      setupHubItem({ to: '/performans-parametreleri', progress: performancePct }),
    ].map((item) =>
      item.to === '/erp'
        ? {
            ...item,
            value: connectorValue,
            hintKey:
              mappingCount > 0 || namespaceCount > 0
                ? 'settingsSetup.setupHub.hints.connectorMapped'
                : item.hintKey,
          }
        : item,
    ),
  }
}

export async function buildDemoSettingsOverview(): Promise<SettingsOverview> {
  const legacy = await fetchDemoSettingsOverview()
  return buildSettingsOverview({
    tenantName: 'Mert Teknik',
    employeeName: 'Demo User',
    employeeLinked: true,
    personaRole: 'hr_admin',
    readiness: {
      core_setup_pct: 100,
      workflow_setup_pct: 100,
      integration_setup_pct: 100,
      performance_setup_pct: 100,
      overall_readiness_pct: 100,
    },
    connection: {
      provider: 'canias',
      display_name: 'Canias',
      is_active: false,
      is_enabled: true,
      setup_status: 'preflight_ready',
      setup_step: 'preflight',
    },
    mappingCount: 12,
    namespaceCount: 1,
    auditCount: legacy.auditLogSensitiveCount,
  })
}

async function fetchRealSettingsOverview(userId: string): Promise<SettingsOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptySettingsOverview()

  const [readiness, connection, mappingCount, namespaceCount, auditCount] = await Promise.all([
    safeSingle<SetupReadinessRow>(
      pulsCalc()
        .from('setup_readiness_summary')
        .select(
          'core_setup_pct, workflow_setup_pct, integration_setup_pct, performance_setup_pct, overall_readiness_pct',
        )
        .eq('tenant_id', ctx.tenantId)
        .maybeSingle(),
    ),
    safeSingle<ConnectionRow>(
      pulsIntegration()
        .from('erp_connections')
        .select('provider, display_name, is_active, is_enabled, setup_status, setup_step')
        .eq('tenant_id', ctx.tenantId)
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle(),
    ),
    safeCount(
      pulsIntegration()
        .from('erp_field_mappings')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId),
    ),
    safeCount(
      pulsIntegration()
        .from('source_namespaces')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId)
        .eq('is_active', true),
    ),
    safeCount(
      pulsAudit()
        .from('audit_logs')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId)
        .gte('occurred_at', auditSince()),
    ),
  ])

  return buildSettingsOverview({
    tenantName: ctx.tenantName,
    employeeName: ctx.employeeName,
    employeeLinked: Boolean(ctx.employeeId),
    personaRole: ctx.personaRole,
    readiness,
    connection,
    mappingCount,
    namespaceCount,
    auditCount,
  })
}

export async function fetchSettingsOverview(userId: string): Promise<SettingsOverview> {
  return resolveAdapterData({
    operation: 'fetchSettingsOverview',
    fetchReal: () => fetchRealSettingsOverview(userId),
    fetchDemo: buildDemoSettingsOverview,
    isEmpty: () => false,
  })
}

export function fetchSettingsOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchSettingsOverview',
    fetchReal: () => fetchRealSettingsOverview(userId),
    fetchDemo: buildDemoSettingsOverview,
    isEmpty: () => false,
  })
}
