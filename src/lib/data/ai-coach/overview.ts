import { fetchDemoAiCoachOverview } from '#/lib/demo/puls-demo-data'
import type { DemoAiCoachOverview } from '#/lib/demo/puls-demo-data'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type AiCoachOverview = DemoAiCoachOverview

const STATIC_AI_COACH_OVERVIEW: AiCoachOverview = {
  capabilities: [
    {
      id: 'a1',
      titleKey: 'aiCoachSetup.capabilities.leavePlan.title',
      descKey: 'aiCoachSetup.capabilities.leavePlan.desc',
    },
    {
      id: 'a2',
      titleKey: 'aiCoachSetup.capabilities.expensePolicy.title',
      descKey: 'aiCoachSetup.capabilities.expensePolicy.desc',
    },
    {
      id: 'a3',
      titleKey: 'aiCoachSetup.capabilities.performanceReminders.title',
      descKey: 'aiCoachSetup.capabilities.performanceReminders.desc',
    },
    {
      id: 'a4',
      titleKey: 'aiCoachSetup.capabilities.careerDevelopment.title',
      descKey: 'aiCoachSetup.capabilities.careerDevelopment.desc',
    },
  ],
  readiness: [
    {
      id: 'r1',
      labelKey: 'aiCoachSetup.readiness.vaultSchema',
      status: 'done',
    },
    {
      id: 'r2',
      labelKey: 'aiCoachSetup.readiness.toolCallLayer',
      status: 'pending',
    },
    {
      id: 'r3',
      labelKey: 'aiCoachSetup.readiness.erpContext',
      status: 'pending',
    },
  ],
}

async function fetchRealAiCoachOverview(_userId: string): Promise<AiCoachOverview> {
  return STATIC_AI_COACH_OVERVIEW
}

export async function fetchAiCoachOverview(userId: string): Promise<AiCoachOverview> {
  return resolveAdapterData({
    operation: 'fetchAiCoachOverview',
    fetchReal: () => fetchRealAiCoachOverview(userId),
    fetchDemo: fetchDemoAiCoachOverview,
    isEmpty: () => false,
  })
}

export function fetchAiCoachOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchAiCoachOverview',
    fetchReal: () => fetchRealAiCoachOverview(userId),
    fetchDemo: fetchDemoAiCoachOverview,
    isEmpty: () => false,
  })
}
