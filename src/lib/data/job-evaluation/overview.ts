import { fetchDemoJobEvaluationOverview } from '#/lib/demo/puls-demo-data'
import type { DemoJobEvaluationOverview } from '#/lib/demo/puls-demo-data'
import { resolveAdapterData } from '#/lib/data/result'

export type JobEvaluationOverview = DemoJobEvaluationOverview

function emptyJobEvaluationOverview(): JobEvaluationOverview {
  return {
    evaluatedPositionCount: 0,
    averageScore: 0,
    highLevelCount: 0,
    missingEvaluationCount: 0,
    maxTotalScore: 1000,
    evaluationFactors: [
      { key: 'knowledge', labelKey: 'jobEvaluationSetup.factors.knowledge', maxScore: 250 },
      { key: 'problem', labelKey: 'jobEvaluationSetup.factors.problem', maxScore: 250 },
      { key: 'responsibility', labelKey: 'jobEvaluationSetup.factors.responsibility', maxScore: 250 },
      { key: 'impact', labelKey: 'jobEvaluationSetup.factors.impact', maxScore: 250 },
    ],
    positions: [],
    levelBands: [
      {
        id: 'lb5',
        levelKey: 'jobEvaluationSetup.bands.level5',
        rangeKey: 'jobEvaluationSetup.levelRanges.level5',
        noteKey: 'jobEvaluationSetup.levelNotes.management',
        tone: 'success',
      },
      {
        id: 'lb4',
        levelKey: 'jobEvaluationSetup.bands.level4',
        rangeKey: 'jobEvaluationSetup.levelRanges.level4',
        noteKey: 'jobEvaluationSetup.levelNotes.seniorExpert',
        tone: 'info',
      },
      {
        id: 'lb3',
        levelKey: 'jobEvaluationSetup.bands.level3',
        rangeKey: 'jobEvaluationSetup.levelRanges.level3',
        noteKey: 'jobEvaluationSetup.levelNotes.expert',
        tone: 'neutral',
      },
    ],
  }
}

function isJobEvaluationOverviewEmpty(data: JobEvaluationOverview): boolean {
  return data.positions.length === 0 && data.evaluatedPositionCount === 0
}

async function fetchRealJobEvaluationOverview(_userId: string): Promise<JobEvaluationOverview> {
  return emptyJobEvaluationOverview()
}

export async function fetchJobEvaluationOverview(userId: string): Promise<JobEvaluationOverview> {
  return resolveAdapterData({
    operation: 'fetchJobEvaluationOverview',
    fetchReal: () => fetchRealJobEvaluationOverview(userId),
    fetchDemo: fetchDemoJobEvaluationOverview,
    isEmpty: isJobEvaluationOverviewEmpty,
  })
}
