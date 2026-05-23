import { fetchDemoTrainingOverview } from '#/lib/demo/puls-demo-data'
import type { DemoTrainingOverview, DemoTrainingStatus } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsPerformance, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type TrainingOverview = DemoTrainingOverview

function mapTrainingStatus(status: string | null | undefined): DemoTrainingStatus {
  switch (status) {
    case 'completed':
      return 'completed'
    case 'planned':
      return 'planned'
    case 'open':
    case 'recommended':
    default:
      return 'suggested'
  }
}

function emptyTrainingOverview(): TrainingOverview {
  return {
    openNeedCount: 0,
    completedCount: 0,
    suggestedCount: 0,
    averageCompletionPercent: 0,
    trainings: [],
  }
}

async function fetchRealTrainingOverview(userId: string): Promise<TrainingOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyTrainingOverview()

  const { data, error } = await pulsPerformance()
    .from('training_needs')
    .select(
      `
      id,
      skill_topic,
      status,
      employees ( full_name )
    `,
    )
    .eq('tenant_id', ctx.tenantId)
    .order('updated_at', { ascending: false })
    .limit(20)

  if (error) {
    throw fromSupabaseError(error, 'fetchTrainingOverview', 'puls_performance', 'training_needs')
  }

  const trainings = (data ?? []).map((row) => {
    const employee = row.employees as { full_name?: string } | null
    return {
      id: row.id as string,
      titleKey: row.skill_topic as string,
      employeeName: employee?.full_name ?? '—',
      competencyKey: row.skill_topic as string,
      hours: 0,
      status: mapTrainingStatus(row.status as string | null),
    }
  })

  const openNeedCount = trainings.filter((row) => row.status !== 'completed').length
  const completedCount = trainings.filter((row) => row.status === 'completed').length
  const suggestedCount = trainings.filter((row) => row.status === 'suggested').length
  const averageCompletionPercent =
    trainings.length > 0 ? Math.round((completedCount / trainings.length) * 100) : 0

  return {
    openNeedCount,
    completedCount,
    suggestedCount,
    averageCompletionPercent,
    trainings,
  }
}

export async function fetchTrainingOverview(userId: string): Promise<TrainingOverview> {
  return resolveAdapterData({
    operation: 'fetchTrainingOverview',
    fetchReal: () => fetchRealTrainingOverview(userId),
    fetchDemo: fetchDemoTrainingOverview,
    isEmpty: (data) => data.trainings.length === 0,
  })
}
