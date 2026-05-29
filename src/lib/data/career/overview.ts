import { fetchDemoCareerOverview } from '#/lib/demo/puls-demo-data'
import type { DemoCareerOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCore, pulsPerformance, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type CareerOverview = DemoCareerOverview

function getInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()
}

function emptyCareerOverview(): CareerOverview {
  return {
    employee: {
      name: '—',
      initials: '—',
      positionKey: '—',
      departmentKey: '—',
    },
    readinessPercent: 0,
    targetRoleKey: '—',
    missingCompetencyCount: 0,
    recommendedTrainingCount: 0,
    ladderSubtitleKey: 'careerSetup.ladder.subtitle',
    careerLadder: [],
    careerGaps: [],
    developmentPlan: { d30: [], d90: [], d180: [] },
  }
}

function isCareerOverviewEmpty(data: CareerOverview): boolean {
  return data.careerLadder.length === 0 && data.readinessPercent === 0 && data.careerGaps.length === 0
}

async function fetchRealCareerOverview(userId: string): Promise<CareerOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId || !ctx.tenantId) return emptyCareerOverview()

  const [employeeRow, profileRow, trainingCount] = await Promise.all([
    pulsCore()
      .from('employees')
      .select(
        `
        full_name,
        departments ( name ),
        positions ( name )
      `,
      )
      .eq('id', ctx.employeeId)
      .maybeSingle(),
    pulsPerformance()
      .from('career_profiles')
      .select('current_step, target_step, readiness_score, missing_competencies')
      .eq('tenant_id', ctx.tenantId)
      .eq('employee_id', ctx.employeeId)
      .maybeSingle(),
    pulsPerformance()
      .from('training_needs')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', ctx.tenantId)
      .eq('employee_id', ctx.employeeId)
      .in('status', ['open', 'recommended', 'planned']),
  ])

  if (employeeRow.error) {
    throw fromSupabaseError(employeeRow.error, 'fetchCareerOverview', 'puls_core', 'employees')
  }
  if (profileRow.error) {
    throw fromSupabaseError(
      profileRow.error,
      'fetchCareerOverview',
      'puls_performance',
      'career_profiles',
    )
  }
  if (trainingCount.error) {
    throw fromSupabaseError(
      trainingCount.error,
      'fetchCareerOverview',
      'puls_performance',
      'training_needs',
    )
  }

  const employeeName = (employeeRow.data?.full_name as string | null) ?? ctx.employeeName ?? '—'
  const department = employeeRow.data?.departments as { name?: string } | null
  const position = employeeRow.data?.positions as { name?: string } | null
  const profile = profileRow.data
  const missingCompetencies = Array.isArray(profile?.missing_competencies)
    ? (profile?.missing_competencies as Array<{ nameKey?: string; current?: number; target?: number; id?: string }>)
    : []

  const careerGaps = missingCompetencies.map((gap, index) => ({
    id: gap.id ?? `gap-${index + 1}`,
    nameKey: gap.nameKey ?? '—',
    current: Number(gap.current ?? 0),
    target: Number(gap.target ?? 0),
  }))

  const currentStep = (profile?.current_step as string | null) ?? '—'
  const targetStep = (profile?.target_step as string | null) ?? '—'

  return {
    employee: {
      name: employeeName,
      initials: getInitials(employeeName),
      positionKey: position?.name ?? '—',
      departmentKey: department?.name ?? '—',
    },
    readinessPercent: Number(profile?.readiness_score ?? 0),
    targetRoleKey: targetStep,
    missingCompetencyCount: careerGaps.length,
    recommendedTrainingCount: trainingCount.count ?? 0,
    ladderSubtitleKey: 'careerSetup.ladder.subtitle',
    careerLadder: [
      {
        level: 1,
        titleKey: currentStep,
        current: true,
        achieved: false,
      },
      {
        level: 2,
        titleKey: targetStep,
        current: false,
        achieved: false,
        target: true,
      },
    ],
    careerGaps,
    developmentPlan: { d30: [], d90: [], d180: [] },
  }
}

export function fetchCareerOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchCareerOverview',
    fetchReal: () => fetchRealCareerOverview(userId),
    fetchDemo: fetchDemoCareerOverview,
    isEmpty: isCareerOverviewEmpty,
  })
}

export async function fetchCareerOverview(userId: string): Promise<CareerOverview> {
  return resolveAdapterData({
    operation: 'fetchCareerOverview',
    fetchReal: () => fetchRealCareerOverview(userId),
    fetchDemo: fetchDemoCareerOverview,
    isEmpty: isCareerOverviewEmpty,
  })
}
