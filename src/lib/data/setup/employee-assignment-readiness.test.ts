import { describe, expect, it } from 'vitest'

import {
  applyEmployeeAssignmentReadinessFilter,
  buildEmployeeAssignmentReadinessFlags,
  buildEmployeeAssignmentReadinessSummary,
  computeEmployeeAssignmentReadiness,
  mapManagerRefFromVisibleRow,
  pickCurrentCostCenterAssignment,
  pickCurrentPrimaryManager,
  type EmployeeAssignmentReadinessEmployee,
} from '#/lib/data/setup/employee-assignment-readiness'

const readyFlags = {
  hasDepartment: true,
  hasPosition: true,
  hasCostCenter: true,
  hasManager: true,
  hasInactiveReference: false,
}

function employee(
  overrides: Partial<EmployeeAssignmentReadinessEmployee> & Pick<EmployeeAssignmentReadinessEmployee, 'id'>,
): EmployeeAssignmentReadinessEmployee {
  return {
    displayName: 'Test Employee',
    email: 'test@example.com',
    employeeNumber: 'E-001',
    isActive: true,
    department: { id: 'd1', name: 'Engineering', code: 'eng', isActive: true },
    position: { id: 'p1', name: 'Engineer', code: 'eng', isActive: true },
    costCenter: { id: 'cc1', name: 'HQ', code: 'HQ', isActive: true },
    manager: { id: 'm1', displayName: 'Manager', email: 'mgr@example.com', isActive: true },
    readiness: {
      status: 'ready',
      flags: readyFlags,
    },
    ...overrides,
  }
}

describe('computeEmployeeAssignmentReadiness', () => {
  it('returns partial only for inactive employees', () => {
    expect(
      computeEmployeeAssignmentReadiness(readyFlags, { isActiveEmployee: false }),
    ).toBe('partial')
  })

  it('returns inactive_reference when any linked ref is inactive', () => {
    const flags = buildEmployeeAssignmentReadinessFlags({
      department: { id: 'd1', name: 'Legacy', code: 'legacy', isActive: false },
      position: { id: 'p1', name: 'Engineer', code: 'eng', isActive: true },
      costCenter: { id: 'cc1', name: 'HQ', code: 'HQ', isActive: true },
      manager: null,
    })

    expect(computeEmployeeAssignmentReadiness(flags, { isActiveEmployee: true })).toBe(
      'inactive_reference',
    )
  })

  it('prefers inactive_reference over missing manager when both apply', () => {
    const flags = buildEmployeeAssignmentReadinessFlags({
      department: { id: 'd1', name: 'Legacy', code: 'legacy', isActive: false },
      position: { id: 'p1', name: 'Engineer', code: 'eng', isActive: true },
      costCenter: { id: 'cc1', name: 'HQ', code: 'HQ', isActive: true },
      manager: null,
    })

    expect(flags.hasInactiveReference).toBe(true)
    expect(flags.hasManager).toBe(false)
    expect(computeEmployeeAssignmentReadiness(flags, { isActiveEmployee: true })).toBe(
      'inactive_reference',
    )
  })

  it('returns each missing status for active employees', () => {
    expect(
      computeEmployeeAssignmentReadiness(
        { ...readyFlags, hasDepartment: false },
        { isActiveEmployee: true },
      ),
    ).toBe('missing_department')
    expect(
      computeEmployeeAssignmentReadiness(
        { ...readyFlags, hasPosition: false },
        { isActiveEmployee: true },
      ),
    ).toBe('missing_position')
    expect(
      computeEmployeeAssignmentReadiness(
        { ...readyFlags, hasCostCenter: false },
        { isActiveEmployee: true },
      ),
    ).toBe('missing_cost_center')
    expect(
      computeEmployeeAssignmentReadiness(
        { ...readyFlags, hasManager: false },
        { isActiveEmployee: true },
      ),
    ).toBe('missing_manager')
    expect(computeEmployeeAssignmentReadiness(readyFlags, { isActiveEmployee: true })).toBe('ready')
  })
})

describe('buildEmployeeAssignmentReadinessSummary', () => {
  it('excludes inactive partial rows from active and gap metrics', () => {
    const summary = buildEmployeeAssignmentReadinessSummary([
      employee({ id: 'e1', readiness: { status: 'ready', flags: readyFlags } }),
      employee({
        id: 'e2',
        isActive: false,
        readiness: { status: 'partial', flags: readyFlags },
      }),
      employee({
        id: 'e3',
        readiness: {
          status: 'missing_department',
          flags: { ...readyFlags, hasDepartment: false },
        },
      }),
    ])

    expect(summary.total).toBe(3)
    expect(summary.active).toBe(2)
    expect(summary.ready).toBe(1)
    expect(summary.missingDepartment).toBe(1)
  })
})

describe('applyEmployeeAssignmentReadinessFilter', () => {
  const employees = [
    employee({ id: 'e1', readiness: { status: 'ready', flags: readyFlags } }),
    employee({
      id: 'e2',
      readiness: {
        status: 'missing_manager',
        flags: { ...readyFlags, hasManager: false },
      },
    }),
  ]

  it('returns all employees for all filter', () => {
    expect(applyEmployeeAssignmentReadinessFilter(employees, 'all')).toHaveLength(2)
  })

  it('filters by readiness status', () => {
    expect(applyEmployeeAssignmentReadinessFilter(employees, 'ready')).toEqual([employees[0]])
    expect(applyEmployeeAssignmentReadinessFilter(employees, 'missing_manager')).toEqual([
      employees[1],
    ])
  })
})

describe('pickCurrentCostCenterAssignment', () => {
  it('chooses active row by starts_on, updated_at, id', () => {
    const picked = pickCurrentCostCenterAssignment([
      {
        id: 'b',
        employee_id: 'e1',
        cost_center_id: 'cc-old',
        starts_on: '2024-01-01',
        updated_at: '2024-06-01T00:00:00Z',
        is_active: true,
      },
      {
        id: 'a',
        employee_id: 'e1',
        cost_center_id: 'cc-new',
        starts_on: '2025-01-01',
        updated_at: '2025-01-01T00:00:00Z',
        is_active: true,
      },
    ])

    expect(picked?.cost_center_id).toBe('cc-new')
  })
})

describe('pickCurrentPrimaryManager', () => {
  it('prefers reporting line over cache when present', () => {
    const managerId = pickCurrentPrimaryManager(
      [
        {
          id: 'rl1',
          employee_id: 'e1',
          manager_employee_id: 'mgr-reporting',
          starts_on: '2025-01-01',
          created_at: '2025-01-01T00:00:00Z',
          is_active: true,
          relationship_type: 'primary_manager',
        },
      ],
      'mgr-cache',
    )

    expect(managerId).toBe('mgr-reporting')
  })

  it('falls back to cache manager id when no reporting line', () => {
    expect(pickCurrentPrimaryManager([], 'mgr-cache')).toBe('mgr-cache')
  })
})

describe('mapManagerRefFromVisibleRow', () => {
  it('keeps readiness manager-positive when RLS hides the manager detail row', () => {
    expect(mapManagerRefFromVisibleRow('mgr-hidden', undefined)).toEqual({
      id: 'mgr-hidden',
      displayName: '—',
      email: null,
      isActive: true,
    })
  })
})
