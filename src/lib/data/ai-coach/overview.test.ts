import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildAiCoachContextDomains,
  buildBlockedAiCoachOverview,
  buildDemoAiCoachOverview,
  deriveAiCoachProductPosture,
  isAiCoachOverviewEmpty,
} from '#/lib/data/ai-coach/context-readiness'
import type { AiCoachContextSnapshot } from '#/lib/data/ai-coach/types'
import { fetchAiCoachOverviewWithMeta } from '#/lib/data/ai-coach/overview'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCalc: vi.fn(),
  pulsCore: vi.fn(),
  pulsWorkflow: vi.fn(),
  pulsPerformance: vi.fn(),
  pulsIntegration: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import { pulsCalc, pulsCore, pulsIntegration, pulsPerformance, pulsWorkflow, resolveTenantContext } from '#/lib/data/client'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)
const resolveTenant = vi.mocked(resolveTenantContext)

function mockTenantContext() {
  return {
    tenantId: 'a0000001-0001-4001-8001-000000000001',
    tenantName: 'Puls Sanayi',
    employeeId: 'a0000006-0006-4006-8006-000000000023',
    employeeName: 'Test Employee',
    personaRole: 'employee' as const,
  }
}

function mockTenantContextWithoutTenant() {
  return {
    tenantId: null,
    tenantName: null,
    employeeId: null,
    employeeName: null,
    personaRole: 'employee' as const,
  }
}

function seededSnapshot(overrides: Partial<AiCoachContextSnapshot> = {}): AiCoachContextSnapshot {
  return {
    tenantPresent: true,
    employeeId: 'a0000006-0006-4006-8006-000000000023',
    employeeName: 'Test Employee',
    setupReadinessPct: 75,
    setupQueryOk: true,
    departmentCount: 12,
    positionCount: 36,
    employeeCount: 120,
    reportingLineCount: 100,
    leaveTypeCount: 8,
    leaveBalanceCount: 120,
    leaveRequestCount: 30,
    expenseCategoryCount: 10,
    expenseClaimCount: 30,
    performanceCycleCount: 1,
    competencyTemplateCount: 10,
    performanceScoreCount: 45,
    competencyEvaluationCount: 45,
    contractCount: 20,
    contractsOverviewPresent: true,
    dashboardOverviewPresent: true,
    sourceNamespaceCount: 1,
    inactiveErpConnectionPresent: true,
    leaveOverviewPresent: true,
    expenseOverviewPresent: true,
    performanceOverviewPresent: true,
    ...overrides,
  }
}

function chain(result: { data?: unknown; count?: number | null; error?: unknown }) {
  const builder = {
    from: vi.fn(() => builder),
    select: vi.fn(() => builder),
    eq: vi.fn(() => builder),
    limit: vi.fn(() => builder),
    maybeSingle: vi.fn(async () => result),
    then(onFulfilled: (value: unknown) => unknown, onRejected?: (reason: unknown) => unknown) {
      return Promise.resolve(result).then(onFulfilled, onRejected)
    },
  }
  return builder
}

function setupSeededMocks() {
  resolveTenant.mockResolvedValue(mockTenantContext())

  vi.mocked(pulsCalc).mockImplementation(() =>
    chain({ data: { overall_readiness_pct: 75, tenant_id: 't' } }) as never,
  )
  vi.mocked(pulsCore).mockImplementation(() => chain({ count: 120, error: null }) as never)
  vi.mocked(pulsWorkflow).mockImplementation(() => chain({ count: 30, error: null }) as never)
  vi.mocked(pulsPerformance).mockImplementation(() => chain({ count: 45, error: null }) as never)
  vi.mocked(pulsIntegration).mockImplementation(() => chain({ count: 1, error: null }) as never)
}

describe('context-readiness pure helpers', () => {
  it('builds 8 context domains from seeded snapshot', () => {
    const domains = buildAiCoachContextDomains(seededSnapshot())
    expect(domains).toHaveLength(8)
    expect(domains.map((domain) => domain.id)).toEqual([
      'setup',
      'employee_quality',
      'leave',
      'expense',
      'performance',
      'contracts',
      'dashboard',
      'profile',
    ])
  })

  it('marks profile partial when employee link missing', () => {
    const domains = buildAiCoachContextDomains(
      seededSnapshot({ employeeId: null, employeeName: null }),
    )
    const profile = domains.find((domain) => domain.id === 'profile')
    expect(profile?.status).toBe('partial')
  })

  it('derives teaser_context_ready when most domains ready', () => {
    const domains = buildAiCoachContextDomains(seededSnapshot())
    expect(deriveAiCoachProductPosture(domains)).toBe('teaser_context_ready')
  })

  it('buildDemoAiCoachOverview returns enriched shape', async () => {
    const overview = await buildDemoAiCoachOverview()
    expect(overview.contextDomains.length).toBeGreaterThan(0)
    expect(overview.guardrails.length).toBeGreaterThanOrEqual(7)
    expect(overview.productPosture).toBe('teaser_context_partial')
  })

  it('blocked overview is empty for isAiCoachOverviewEmpty', () => {
    const blocked = buildBlockedAiCoachOverview()
    expect(isAiCoachOverviewEmpty(blocked)).toBe(true)
  })
})

describe('fetchAiCoachOverviewWithMeta', () => {
  afterEach(() => {
    vi.clearAllMocks()
  })

  it('returns real success with 8 domains when tenant is seeded', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks()

    const result = await fetchAiCoachOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.contextDomains).toHaveLength(8)
    expect(result.data.guardrails.some((g) => g.id === 'g3')).toBe(true)
    expect(result.data.guardrails.some((g) => g.id === 'g4')).toBe(true)
  })

  it('returns real blocked overview without demo fallback when demo mode off', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchAiCoachOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data.contextDomains.every((domain) => domain.status === 'blocked')).toBe(true)
  })

  it('returns demo fallback when demo mode on and tenant missing', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchAiCoachOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.fallbackReason).toBe('empty')
    expect(result.data.contextDomains.length).toBeGreaterThan(0)
    expect(result.data.guardrails.length).toBeGreaterThanOrEqual(7)
  })

  it('still returns overview when count queries return errors', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContext())
    vi.mocked(pulsCalc).mockImplementation(() =>
      chain({ data: { overall_readiness_pct: 75 }, error: null }) as never,
    )
    vi.mocked(pulsCore).mockImplementation(() =>
      chain({ count: null, error: { message: 'simulated failure' } }) as never,
    )
    vi.mocked(pulsWorkflow).mockImplementation(() => chain({ count: 30, error: null }) as never)
    vi.mocked(pulsPerformance).mockImplementation(() => chain({ count: 45, error: null }) as never)
    vi.mocked(pulsIntegration).mockImplementation(() => chain({ count: 1, error: null }) as never)

    const result = await fetchAiCoachOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.contextDomains.length).toBe(8)
    const employeeQuality = result.data.contextDomains.find((d) => d.id === 'employee_quality')
    expect(employeeQuality?.status).toBe('partial')
  })
})
