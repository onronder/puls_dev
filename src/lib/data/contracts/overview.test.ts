import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  fetchContractsOverviewWithMeta,
  getContractInitials,
  mapContractRiskStatus,
  mapContractRow,
  mapContractSignatureStatus,
} from '#/lib/data/contracts/overview'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCalc: vi.fn(),
  pulsCore: vi.fn(),
  pulsWorkflow: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import { pulsCalc, pulsCore, pulsWorkflow, resolveTenantContext } from '#/lib/data/client'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)
const resolveTenant = vi.mocked(resolveTenantContext)
const pulsCalcMock = vi.mocked(pulsCalc)
const pulsCoreMock = vi.mocked(pulsCore)
const pulsWorkflowMock = vi.mocked(pulsWorkflow)

function mockTenantContextWithoutTenant() {
  return {
    tenantId: null,
    tenantName: null,
    employeeId: null,
    employeeName: null,
    personaRole: 'employee' as const,
  }
}

function mockTenantContext() {
  return {
    tenantId: 'tenant-1',
    tenantName: 'Tenant',
    employeeId: 'employee-1',
    employeeName: 'Employee One',
    personaRole: 'employee' as const,
  }
}

function queryChain(result: { data?: unknown; error?: unknown }) {
  const builder = {
    select: vi.fn(() => builder),
    eq: vi.fn(() => builder),
    in: vi.fn(async () => result),
    order: vi.fn(() => builder),
    limit: vi.fn(async () => result),
    maybeSingle: vi.fn(async () => result),
  }
  return builder
}

describe('getContractInitials', () => {
  it('returns up to two uppercase initials from a full name', () => {
    expect(getContractInitials('Ayşe Kaya')).toBe('AK')
  })
})

describe('mapContractSignatureStatus', () => {
  it('maps awaiting to pending', () => {
    expect(mapContractSignatureStatus('awaiting')).toBe('pending')
  })

  it('maps signed, not_required, and null to signed', () => {
    expect(mapContractSignatureStatus('signed')).toBe('signed')
    expect(mapContractSignatureStatus('not_required')).toBe('signed')
    expect(mapContractSignatureStatus(null)).toBe('signed')
  })
})

describe('mapContractRiskStatus', () => {
  const now = new Date('2026-05-20T12:00:00')

  it('returns pending when signature is awaiting', () => {
    expect(
      mapContractRiskStatus({
        signatureStatus: 'awaiting',
        endDate: '2026-06-01',
        riskBand: 'low',
        now,
      }),
    ).toBe('pending')
  })

  it('returns expiring when end date is within 60 days', () => {
    expect(
      mapContractRiskStatus({
        signatureStatus: 'signed',
        endDate: '2026-06-01',
        riskBand: 'low',
        now,
      }),
    ).toBe('expiring')
  })

  it('returns expiring for medium or high risk band', () => {
    expect(
      mapContractRiskStatus({
        signatureStatus: 'signed',
        endDate: null,
        riskBand: 'high',
        now,
      }),
    ).toBe('expiring')
  })

  it('returns ok for low risk without near end date', () => {
    expect(
      mapContractRiskStatus({
        signatureStatus: 'signed',
        endDate: '2027-01-01',
        riskBand: 'low',
        now,
      }),
    ).toBe('ok')
  })
})

describe('mapContractRow', () => {
  it('maps employee, type key, dates, signature, and risk', () => {
    expect(
      mapContractRow(
        {
          id: 'c-1',
          contract_type: 'fixed_term',
          start_date: '2024-01-01',
          end_date: '2026-06-01',
          signature_status: 'awaiting',
          risk_band: 'low',
          employees: { full_name: 'Murat Tan' },
        },
        { now: new Date('2026-05-20T12:00:00') },
      ),
    ).toEqual({
      id: 'c-1',
      employeeName: 'Murat Tan',
      initials: 'MT',
      typeKey: 'contractsSetup.types.fixedTerm',
      startDate: '2024-01-01',
      endDate: '2026-06-01',
      signed: 'pending',
      risk: 'pending',
    })
  })
})

describe('fetchContractsOverviewWithMeta', () => {
  afterEach(() => {
    demoEnabled.mockReset()
    resolveTenant.mockReset()
    pulsCalcMock.mockReset()
    pulsCoreMock.mockReset()
    pulsWorkflowMock.mockReset()
  })

  it('real empty tenant returns source real and status empty', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchContractsOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data.contracts).toEqual([])
  })

  it('uses demo fixture when demo mode is on and real is empty', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchContractsOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.data.contracts.length).toBeGreaterThan(0)
    expect(result.data.activeContractCount).toBeGreaterThan(0)
  })

  it('fetches real contracts and resolves employee names with a separate core query', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContext())

    pulsCalcMock.mockReturnValue({
      from: vi.fn(() =>
        queryChain({
          data: { active_contract_count: 20, expiring_contract_count: 2 },
          error: null,
        }),
      ),
    } as never)
    pulsWorkflowMock.mockReturnValue({
      from: vi.fn(() =>
        queryChain({
          data: [
            {
              id: 'contract-1',
              employee_id: 'employee-1',
              contract_type: 'employment',
              start_date: '2026-01-01',
              end_date: null,
              signature_status: 'signed',
              risk_band: 'low',
            },
          ],
          error: null,
        }),
      ),
    } as never)
    pulsCoreMock.mockReturnValue({
      from: vi.fn(() =>
        queryChain({
          data: [{ id: 'employee-1', full_name: 'Burak Aslan' }],
          error: null,
        }),
      ),
    } as never)

    const result = await fetchContractsOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.activeContractCount).toBe(20)
    expect(result.data.contracts).toEqual([
      expect.objectContaining({
        employeeName: 'Burak Aslan',
        typeKey: 'contractsSetup.types.indefinite',
      }),
    ])
  })
})
