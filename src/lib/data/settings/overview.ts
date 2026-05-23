import { fetchDemoSettingsOverview } from '#/lib/demo/puls-demo-data'
import type { DemoSettingsOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsAudit, pulsCalc, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type SettingsOverview = DemoSettingsOverview

const STATIC_SETTINGS_SECTIONS: SettingsOverview['sections'] = [
  {
    id: 'accountSecurity',
    titleKey: 'settingsSetup.sections.accountSecurity.title',
    summaryKey: 'settingsSetup.sections.accountSecurity.summary',
    actionKey: 'settingsSetup.sections.accountSecurity.action',
    sheetDescriptionKey: 'settingsSetup.sections.accountSecurity.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.accountSecurity.sheetBody',
  },
  {
    id: 'tenant',
    titleKey: 'settingsSetup.sections.tenant.title',
    summaryKey: 'settingsSetup.sections.tenant.summary',
    actionKey: 'settingsSetup.sections.tenant.action',
    sheetDescriptionKey: 'settingsSetup.sections.tenant.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.tenant.sheetBody',
  },
  {
    id: 'notifications',
    titleKey: 'settingsSetup.sections.notifications.title',
    summaryKey: 'settingsSetup.sections.notifications.summary',
    actionKey: 'settingsSetup.sections.notifications.action',
    sheetDescriptionKey: 'settingsSetup.sections.notifications.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.notifications.sheetBody',
  },
  {
    id: 'locale',
    titleKey: 'settingsSetup.sections.locale.title',
    summaryKey: 'settingsSetup.sections.locale.summary',
    actionKey: 'settingsSetup.sections.locale.action',
    sheetDescriptionKey: 'settingsSetup.sections.locale.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.locale.sheetBody',
  },
  {
    id: 'theme',
    titleKey: 'settingsSetup.sections.theme.title',
    summaryKey: 'settingsSetup.sections.theme.summary',
    actionKey: 'settingsSetup.sections.theme.action',
    sheetDescriptionKey: 'settingsSetup.sections.theme.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.theme.sheetBody',
  },
  {
    id: 'roleAccess',
    titleKey: 'settingsSetup.sections.roleAccess.title',
    summaryKey: 'settingsSetup.sections.roleAccess.summary',
    actionKey: 'settingsSetup.sections.roleAccess.action',
    sheetDescriptionKey: 'settingsSetup.sections.roleAccess.sheetDescription',
    sheetBodyKey: 'settingsSetup.sections.roleAccess.sheetBody',
  },
]

function emptySettingsOverview(): SettingsOverview {
  return {
    auditLogDays: 30,
    auditLogSensitiveCount: 0,
    sections: STATIC_SETTINGS_SECTIONS,
  }
}

async function fetchRealSettingsOverview(userId: string): Promise<SettingsOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptySettingsOverview()

  const since = new Date()
  since.setDate(since.getDate() - 30)

  const [readinessRow, auditCount] = await Promise.all([
    pulsCalc()
      .from('setup_readiness_summary')
      .select('overall_readiness_pct')
      .eq('tenant_id', ctx.tenantId)
      .maybeSingle(),
    pulsAudit()
      .from('audit_logs')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', ctx.tenantId)
      .gte('occurred_at', since.toISOString()),
  ])

  if (readinessRow.error) {
    throw fromSupabaseError(
      readinessRow.error,
      'fetchSettingsOverview',
      'puls_calc',
      'setup_readiness_summary',
    )
  }
  if (auditCount.error) {
    throw fromSupabaseError(auditCount.error, 'fetchSettingsOverview', 'puls_audit', 'audit_logs')
  }

  return {
    auditLogDays: 30,
    auditLogSensitiveCount: 0,
    sections: STATIC_SETTINGS_SECTIONS,
  }
}

export async function fetchSettingsOverview(userId: string): Promise<SettingsOverview> {
  return resolveAdapterData({
    operation: 'fetchSettingsOverview',
    fetchReal: () => fetchRealSettingsOverview(userId),
    fetchDemo: fetchDemoSettingsOverview,
    isEmpty: () => false,
  })
}
