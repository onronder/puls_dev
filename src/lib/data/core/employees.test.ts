import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildEmployeeListStats,
  emptyEmployeeListStats,
  fetchEmployeeListStatsWithMeta,
  isActiveEmployeeStatus,
  mapEmployeeRow,
  type EmployeeListItem,
} from '#/lib/data/core/employees'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/demo/puls-demo-data', () => ({
  fetchDemoEmployeeAssignmentReadiness: vi.fn(async () => ({
    employees: [
      {
        id: 'demo-e-ready',
        displayName: 'Murat Tan',
        email: 'murat.tan@mertteknik.com',
        employeeNumber: 'MT-001',
        isActive: true,
        department: { id: 'd1', name: 'Mühendislik', code: 'eng', isActive: true },
        position: { id: 'p2', name: 'Saha Mühendisi', code: 'field', isActive: true },
        costCenter: null,
        manager: { id: 'm1', displayName: 'Demo Manager', email: null, isActive: true },
        readiness: { status: 'ready', flags: {} },
      },
      {
        id: 'demo-e-no-dept',
        displayName: 'Ayşe Kaya',
        email: 'ayse@mertteknik.com',
        employeeNumber: 'AK-002',
        isActive: true,
        department: null,
        position: { id: 'p2', name: 'Saha Mühendisi', code: 'field', isActive: true },
        costCenter: null,
        manager: null,
        readiness: { status: 'missing_department', flags: {} },
      },
    ],
    summary: {
      total: 2,
      active: 2,
      ready: 1,
      missingDepartment: 1,
      missingPosition: 0,
      missingCostCenter: 0,
      missingManager: 1,
      inactiveReferences: 0,
    },
  })),
  fetchDemoEmployeesOverview: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCore: vi.fn(),
  pulsCalc: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import { pulsCore, resolveTenantContext } from '#/lib/data/client'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)
const resolveTenant = vi.mocked(resolveTenantContext)
const pulsCoreMock = vi.mocked(pulsCore)

function mockEmptyEmployeeQuery() {
  const chain = {
    select: vi.fn(),
    eq: vi.fn(),
    order: vi.fn(),
  }
  chain.select.mockReturnValue(chain)
  chain.eq.mockReturnValue(chain)
  chain.order.mockResolvedValue({ data: [], error: null })
  pulsCoreMock.mockReturnValue({ from: vi.fn().mockReturnValue(chain) } as never)
}

const baseRow = {
  id: 'e1',
  full_name: 'Murat Tan',
  email: 'murat@mertteknik.com',
  employee_code: 'MT-001',
  employment_status: 'active',
  job_title: 'Engineer',
  persona_role: 'employee',
  hire_date: '2024-01-01',
  department_id: 'd1',
  position_id: 'p1',
  manager_employee_id: 'm1',
}

const emptyLookups = {
  departmentNameMap: new Map<string, string>(),
  positionNameMap: new Map<string, string>(),
  managerNameMap: new Map<string, string>(),
}

describe('isActiveEmployeeStatus', () => {
  it('returns true only for active', () => {
    expect(isActiveEmployeeStatus('active')).toBe(true)
    expect(isActiveEmployeeStatus('terminated')).toBe(false)
    expect(isActiveEmployeeStatus(null)).toBe(false)
    expect(isActiveEmployeeStatus(undefined)).toBe(false)
  })
})

describe('mapEmployeeRow', () => {
  it('maps row with lookup names and manager display field', () => {
    const item = mapEmployeeRow(baseRow, {
      departmentNameMap: new Map([['d1', 'Engineering']]),
      positionNameMap: new Map([['p1', 'Field Engineer']]),
      managerNameMap: new Map([['m1', 'Demo Manager']]),
    })

    expect(item).toMatchObject({
      id: 'e1',
      fullName: 'Murat Tan',
      employeeNumber: 'MT-001',
      isActive: true,
      departmentName: 'Engineering',
      positionName: 'Field Engineer',
      managerEmployeeId: 'm1',
      managerName: 'Demo Manager',
    })
  })

  it('leaves missing FK names null', () => {
    const item = mapEmployeeRow(
      { ...baseRow, department_id: null, position_id: null, manager_employee_id: null },
      emptyLookups,
    )

    expect(item.departmentName).toBeNull()
    expect(item.positionName).toBeNull()
    expect(item.managerName).toBeNull()
  })
})

describe('buildEmployeeListStats', () => {
  it('computes totals and missing FK counts from manager_employee_id only', () => {
    const items: EmployeeListItem[] = [
      mapEmployeeRow(baseRow, {
        departmentNameMap: new Map([['d1', 'Engineering']]),
        positionNameMap: new Map([['p1', 'Field Engineer']]),
        managerNameMap: new Map([['m1', 'Demo Manager']]),
      }),
      mapEmployeeRow(
        {
          ...baseRow,
          id: 'e2',
          employment_status: 'terminated',
          department_id: null,
          position_id: null,
          manager_employee_id: null,
        },
        emptyLookups,
      ),
    ]

    expect(buildEmployeeListStats(items)).toEqual({
      total: 2,
      active: 1,
      inactive: 1,
      missingDepartment: 1,
      missingPosition: 1,
      missingManager: 1,
    })
  })

  it('returns all zeros for empty list', () => {
    expect(buildEmployeeListStats([])).toEqual(emptyEmployeeListStats())
  })
})

describe('fetchEmployeeListStatsWithMeta', () => {
  afterEach(() => {
    demoEnabled.mockReset()
    resolveTenant.mockReset()
  })

  it('real empty tenant returns zero stats, not fake demo stats', async () => {
    demoEnabled.mockReturnValue(false)
    mockEmptyEmployeeQuery()
    resolveTenant.mockResolvedValue({
      tenantId: 'tenant-1',
      tenantName: 'Tenant',
      employeeId: null,
      employeeName: null,
      personaRole: 'manager',
    })

    const result = await fetchEmployeeListStatsWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data).toEqual(emptyEmployeeListStats())
    expect(result.data.total).toBe(0)
    expect(result.data.active).toBe(0)
  })

  it('uses centralized demo fixture when demo mode is on and real is empty', async () => {
    demoEnabled.mockReturnValue(true)
    mockEmptyEmployeeQuery()
    resolveTenant.mockResolvedValue({
      tenantId: 'tenant-1',
      tenantName: 'Tenant',
      employeeId: null,
      employeeName: null,
      personaRole: 'manager',
    })

    const result = await fetchEmployeeListStatsWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.data.total).toBe(2)
    expect(result.data.missingDepartment).toBe(1)
    expect(result.data.missingManager).toBe(1)
  })
})
