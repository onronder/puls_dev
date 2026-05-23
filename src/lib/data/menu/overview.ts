import { fetchDemoMenuTenantFallback } from '#/lib/demo/puls-demo-data'
import type { DemoMenuTenantFallback } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type MenuOverview = DemoMenuTenantFallback & {
  displayName: string | null
  tenantName: string | null
  jobTitle: string | null
}

function emptyMenuOverview(ctx?: {
  displayName?: string | null
  tenantName?: string | null
}): MenuOverview {
  return {
    displayName: ctx?.displayName ?? null,
    tenantName: ctx?.tenantName ?? null,
    jobTitle: null,
    employeeCount: 0,
    departmentCount: 0,
    positionCount: 0,
  }
}

function isMenuOverviewEmpty(data: MenuOverview): boolean {
  return (
    data.employeeCount === 0 &&
    data.departmentCount === 0 &&
    data.positionCount === 0 &&
    data.displayName == null
  )
}

async function fetchRealMenuOverview(userId: string): Promise<MenuOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    return emptyMenuOverview({
      displayName: ctx.employeeName,
      tenantName: ctx.tenantName,
    })
  }

  if (!ctx.employeeId) {
    return emptyMenuOverview({
      displayName: ctx.employeeName,
      tenantName: ctx.tenantName,
    })
  }

  const { data, error } = await pulsCalc()
    .from('menu_overview')
    .select('display_name, job_title, tenant_name, employee_count, department_count, position_count')
    .eq('tenant_id', ctx.tenantId)
    .eq('employee_id', ctx.employeeId)
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'fetchMenuOverview', 'puls_calc', 'menu_overview')
  }

  if (!data) {
    return emptyMenuOverview({
      displayName: ctx.employeeName,
      tenantName: ctx.tenantName,
    })
  }

  return {
    displayName: (data.display_name as string | null) ?? ctx.employeeName,
    tenantName: (data.tenant_name as string | null) ?? ctx.tenantName,
    jobTitle: (data.job_title as string | null) ?? null,
    employeeCount: Number(data.employee_count ?? 0),
    departmentCount: Number(data.department_count ?? 0),
    positionCount: Number(data.position_count ?? 0),
  }
}

export async function fetchMenuOverview(userId: string): Promise<MenuOverview> {
  return resolveAdapterData({
    operation: 'fetchMenuOverview',
    fetchReal: () => fetchRealMenuOverview(userId),
    fetchDemo: async () => {
      const [fallback, ctx] = await Promise.all([
        fetchDemoMenuTenantFallback(),
        resolveTenantContext(userId),
      ])
      return {
        ...fallback,
        displayName: ctx.employeeName ?? 'Demo Kullanıcı',
        tenantName: ctx.tenantName ?? 'Mert Teknik A.Ş.',
        jobTitle: null,
      }
    },
    isEmpty: isMenuOverviewEmpty,
  })
}
