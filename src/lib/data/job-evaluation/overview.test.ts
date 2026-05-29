import { afterEach, describe, expect, it, vi } from 'vitest'

import { fetchJobEvaluationOverviewWithMeta } from '#/lib/data/job-evaluation/overview'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)

describe('fetchJobEvaluationOverviewWithMeta', () => {
  afterEach(() => {
    demoEnabled.mockReset()
  })

  it('real empty tenant returns source real and status empty', async () => {
    demoEnabled.mockReturnValue(false)

    const result = await fetchJobEvaluationOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data.positions).toEqual([])
    expect(result.data.evaluatedPositionCount).toBe(0)
  })

  it('uses demo fixture when demo mode is on and real is empty', async () => {
    demoEnabled.mockReturnValue(true)

    const result = await fetchJobEvaluationOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.data.positions.length).toBeGreaterThan(0)
    expect(result.data.evaluatedPositionCount).toBeGreaterThan(0)
  })
})
