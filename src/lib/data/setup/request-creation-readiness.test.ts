import { describe, expect, it } from 'vitest'

import {
  buildExpenseCreationReadiness,
  buildLeaveCreationReadiness,
  getPrimaryRequestCreationBlocker,
  mapPolicyStatusToWarning,
  type RequestCreationBlocker,
  type RequestCreationWarning,
} from '#/lib/data/setup/request-creation-readiness'
import type { EmployeeAssignmentReadinessEmployee } from '#/lib/data/setup/employee-assignment-readiness'
import { buildApprovalPolicyBindingInfo } from '#/lib/data/workflow/policy-binding-readiness'

const readyFlags = {
  hasDepartment: true,
  hasPosition: true,
  hasCostCenter: true,
  hasManager: true,
  hasInactiveReference: false,
}

function assignment(
  overrides: Partial<EmployeeAssignmentReadinessEmployee> &
    Pick<EmployeeAssignmentReadinessEmployee, 'id'>,
): EmployeeAssignmentReadinessEmployee {
  return {
    displayName: 'Test Employee',
    email: 'test@example.com',
    employeeNumber: 'E-001',
    isActive: true,
    source: 'puls',
    canEditAssignment: true,
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

const readyPolicyTarget = {
  id: 'cat-1',
  approvalPolicy: buildApprovalPolicyBindingInfo({
    expectedModule: 'expense',
    policyId: 'policy-1',
    policyName: 'Expense policy',
    policyModule: 'expense',
    policyIsActive: true,
    requiredStepCount: 1,
  }),
}

const unboundPolicyTarget = {
  id: 'cat-2',
  approvalPolicy: buildApprovalPolicyBindingInfo({
    expectedModule: 'expense',
    policyId: null,
    policyModule: null,
    policyIsActive: null,
    requiredStepCount: 0,
  }),
}

const FORBIDDEN_BLOCKERS = ['missing_manager', 'policy_not_ready'] as const

function assertNoForbiddenBlockers(blockers: RequestCreationBlocker[]) {
  for (const forbidden of FORBIDDEN_BLOCKERS) {
    expect(blockers).not.toContain(forbidden)
  }
}

describe('buildExpenseCreationReadiness', () => {
  it('blocks when no active categories', () => {
    const result = buildExpenseCreationReadiness({
      activeCategoryCount: 0,
      assignment: assignment({ id: 'e1' }),
      policyTargets: [],
    })

    expect(result.canCreate).toBe(false)
    expect(result.blockers).toContain('no_active_expense_categories')
    assertNoForbiddenBlockers(result.blockers)
  })

  it('blocks expense when cost center is missing', () => {
    const result = buildExpenseCreationReadiness({
      activeCategoryCount: 2,
      assignment: assignment({
        id: 'e1',
        costCenter: null,
        readiness: {
          status: 'missing_cost_center',
          flags: { ...readyFlags, hasCostCenter: false },
        },
      }),
      policyTargets: [readyPolicyTarget],
    })

    expect(result.canCreate).toBe(false)
    expect(result.blockers).toContain('missing_cost_center')
    assertNoForbiddenBlockers(result.blockers)
  })

  it('blocks when assignment reference is inactive', () => {
    const result = buildExpenseCreationReadiness({
      activeCategoryCount: 2,
      assignment: assignment({
        id: 'e1',
        readiness: {
          status: 'inactive_reference',
          flags: { ...readyFlags, hasInactiveReference: true },
        },
      }),
      policyTargets: [readyPolicyTarget],
    })

    expect(result.blockers).toContain('inactive_assignment_reference')
    assertNoForbiddenBlockers(result.blockers)
  })

  it('blocks inactive employees with assignment_partial', () => {
    const result = buildExpenseCreationReadiness({
      activeCategoryCount: 2,
      assignment: assignment({
        id: 'e1',
        isActive: false,
        readiness: {
          status: 'partial',
          flags: readyFlags,
        },
      }),
      policyTargets: [readyPolicyTarget],
    })

    expect(result.canCreate).toBe(false)
    expect(result.blockers).toContain('assignment_partial')
    assertNoForbiddenBlockers(result.blockers)
  })

  it('warns on missing manager without blocking', () => {
    const result = buildExpenseCreationReadiness({
      activeCategoryCount: 2,
      assignment: assignment({
        id: 'e1',
        manager: null,
        readiness: {
          status: 'missing_manager',
          flags: { ...readyFlags, hasManager: false },
        },
      }),
      policyTargets: [readyPolicyTarget],
    })

    expect(result.canCreate).toBe(true)
    expect(result.warnings).toContain('missing_manager')
    expect(result.blockers).not.toContain('missing_manager')
    assertNoForbiddenBlockers(result.blockers)
  })

  it('warns when policy targets are not ready', () => {
    const result = buildExpenseCreationReadiness({
      activeCategoryCount: 1,
      assignment: assignment({ id: 'e1' }),
      policyTargets: [unboundPolicyTarget],
    })

    expect(result.canCreate).toBe(true)
    expect(result.warnings).toContain('policy_unbound')
    assertNoForbiddenBlockers(result.blockers)
  })

  it('blocks a selected expense category that is no longer active', () => {
    const result = buildExpenseCreationReadiness({
      activeCategoryCount: 1,
      assignment: assignment({ id: 'e1' }),
      policyTargets: [readyPolicyTarget],
      selectedCategoryId: 'inactive-cat',
    })

    expect(result.canCreate).toBe(false)
    expect(result.blockers).toContain('invalid_expense_category')
    assertNoForbiddenBlockers(result.blockers)
  })
})

describe('buildLeaveCreationReadiness', () => {
  it('blocks when no active leave types', () => {
    const result = buildLeaveCreationReadiness({
      activeLeaveTypeCount: 0,
      assignment: assignment({ id: 'e1' }),
      policyTargets: [],
    })

    expect(result.blockers).toContain('no_active_leave_types')
    assertNoForbiddenBlockers(result.blockers)
  })

  it('warns on missing cost center for leave', () => {
    const result = buildLeaveCreationReadiness({
      activeLeaveTypeCount: 2,
      assignment: assignment({
        id: 'e1',
        costCenter: null,
        readiness: {
          status: 'missing_cost_center',
          flags: { ...readyFlags, hasCostCenter: false },
        },
      }),
      policyTargets: [readyPolicyTarget],
    })

    expect(result.canCreate).toBe(true)
    expect(result.warnings).toContain('missing_cost_center')
    expect(result.blockers).not.toContain('missing_cost_center')
    assertNoForbiddenBlockers(result.blockers)
  })

  it('blocks inactive employees with assignment_partial', () => {
    const result = buildLeaveCreationReadiness({
      activeLeaveTypeCount: 2,
      assignment: assignment({
        id: 'e1',
        isActive: false,
        readiness: {
          status: 'partial',
          flags: readyFlags,
        },
      }),
      policyTargets: [readyPolicyTarget],
    })

    expect(result.blockers).toContain('assignment_partial')
    assertNoForbiddenBlockers(result.blockers)
  })

  it('blocks a selected leave type that is no longer active', () => {
    const result = buildLeaveCreationReadiness({
      activeLeaveTypeCount: 1,
      assignment: assignment({ id: 'e1' }),
      policyTargets: [readyPolicyTarget],
      selectedLeaveTypeId: 'inactive-leave-type',
    })

    expect(result.canCreate).toBe(false)
    expect(result.blockers).toContain('invalid_leave_type')
    assertNoForbiddenBlockers(result.blockers)
  })
})

describe('getPrimaryRequestCreationBlocker', () => {
  it('prefers inactive reference over assignment partial and missing cost center', () => {
    const readiness = buildExpenseCreationReadiness({
      activeCategoryCount: 0,
      assignment: assignment({
        id: 'e1',
        isActive: false,
        costCenter: null,
        readiness: {
          status: 'partial',
          flags: { ...readyFlags, hasCostCenter: false },
        },
      }),
      policyTargets: [],
    })

    expect(getPrimaryRequestCreationBlocker(readiness)).toBe('assignment_partial')
  })

  it('prefers inactive reference over other blockers for active employees', () => {
    const readiness = buildExpenseCreationReadiness({
      activeCategoryCount: 0,
      assignment: assignment({
        id: 'e1',
        readiness: {
          status: 'inactive_reference',
          flags: { ...readyFlags, hasInactiveReference: true, hasCostCenter: false },
        },
      }),
      policyTargets: [],
    })

    expect(getPrimaryRequestCreationBlocker(readiness)).toBe('inactive_assignment_reference')
  })
})

describe('mapPolicyStatusToWarning', () => {
  it('maps binding statuses to warning codes', () => {
    const cases: Array<[ReturnType<typeof mapPolicyStatusToWarning>, RequestCreationWarning]> = [
      [mapPolicyStatusToWarning('unbound'), 'policy_unbound'],
      [mapPolicyStatusToWarning('inactive_policy'), 'policy_inactive'],
      [mapPolicyStatusToWarning('missing_required_steps'), 'policy_missing_steps'],
      [mapPolicyStatusToWarning('module_mismatch'), 'policy_module_mismatch'],
    ]

    for (const [actual, expected] of cases) {
      expect(actual).toBe(expected)
    }
  })
})
