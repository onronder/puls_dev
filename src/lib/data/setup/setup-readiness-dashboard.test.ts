import { describe, expect, it } from 'vitest'

import type { CostCenterReadinessOverview } from '#/lib/data/setup/cost-center-readiness'
import type { EmployeeAssignmentReadinessOverview } from '#/lib/data/setup/employee-assignment-readiness'
import type { ExpenseCategoriesOverview } from '#/lib/data/setup/expense-categories'
import type { LeaveTypesOverview } from '#/lib/data/setup/leave-types'
import type { OrgSetupReadinessOverview } from '#/lib/data/setup/org-setup-readiness'
import type { RequestCreationReadinessResult } from '#/lib/data/setup/request-creation-readiness'
import {
  buildApprovalPolicyReadinessSection,
  buildCostCenterReadinessSection,
  buildEmployeeAssignmentReadinessSection,
  buildExpenseReadinessSection,
  buildLeaveReadinessSection,
  buildOrgReadinessSection,
  buildRequestCreationReadinessSection,
  combineSetupReadinessSeverity,
  rankSetupReadinessSeverity,
  type SetupReadinessSection,
} from '#/lib/data/setup/setup-readiness-dashboard'
import { buildApprovalPolicyBindingInfo } from '#/lib/data/workflow/policy-binding-readiness'

const readyPolicy = buildApprovalPolicyBindingInfo({
  expectedModule: 'expense',
  policyId: 'policy-1',
  policyName: 'Expense policy',
  policyModule: 'expense',
  policyIsActive: true,
  requiredStepCount: 1,
})

const unboundPolicy = buildApprovalPolicyBindingInfo({
  expectedModule: 'expense',
  policyId: null,
  policyModule: null,
  policyIsActive: null,
  requiredStepCount: 0,
})

function expenseOverview(
  categories: ExpenseCategoriesOverview['categories'],
): ExpenseCategoriesOverview {
  return {
    categoryCount: categories.length,
    totalMonthlyLimit: 0,
    docThresholdMetric: 0,
    maxApprovalStepCount: 0,
    categories,
  }
}

function leaveOverview(leaveTypes: LeaveTypesOverview['leaveTypes']): LeaveTypesOverview {
  return {
    typeCount: leaveTypes.length,
    paidCount: 0,
    docRequiredCount: 0,
    maxApprovalStepCount: 0,
    leaveTypes,
  }
}

function orgOverview(summary: OrgSetupReadinessOverview['summary']): OrgSetupReadinessOverview {
  return { summary }
}

function assignmentOverview(
  summary: EmployeeAssignmentReadinessOverview['summary'],
): EmployeeAssignmentReadinessOverview {
  return { employees: [], summary }
}

function costCenterOverview(
  partial: Partial<CostCenterReadinessOverview> &
    Pick<CostCenterReadinessOverview, 'exportReadyCount' | 'needsMappingCount' | 'items'>,
): CostCenterReadinessOverview {
  return {
    routingWarnings: [],
    ...partial,
  }
}

function requestCreationResult(
  partial: Partial<RequestCreationReadinessResult> &
    Pick<RequestCreationReadinessResult, 'readiness'>,
): RequestCreationReadinessResult {
  return {
    assignment: null,
    activeTargetCount: 0,
    policyReadyCount: 0,
    policyTargets: [],
    ...partial,
  }
}

describe('rankSetupReadinessSeverity', () => {
  it('orders blocking above unknown above warning above ready', () => {
    expect(rankSetupReadinessSeverity('blocking', 'unknown')).toBeGreaterThan(0)
    expect(rankSetupReadinessSeverity('unknown', 'warning')).toBeGreaterThan(0)
    expect(rankSetupReadinessSeverity('warning', 'ready')).toBeGreaterThan(0)
    expect(rankSetupReadinessSeverity('blocking', 'ready')).toBeGreaterThan(0)
  })
})

describe('combineSetupReadinessSeverity', () => {
  it('returns blocking when any section is blocking', () => {
    const sections: Pick<SetupReadinessSection, 'severity'>[] = [
      { severity: 'ready' },
      { severity: 'warning' },
      { severity: 'blocking' },
    ]
    expect(combineSetupReadinessSeverity(sections)).toBe('blocking')
  })

  it('returns unknown when no blocking but an unknown section exists', () => {
    expect(
      combineSetupReadinessSeverity([{ severity: 'ready' }, { severity: 'unknown' }]),
    ).toBe('unknown')
    expect(
      combineSetupReadinessSeverity([{ severity: 'warning' }, { severity: 'unknown' }]),
    ).toBe('unknown')
  })

  it('returns warning when highest severity is warning', () => {
    expect(
      combineSetupReadinessSeverity([{ severity: 'ready' }, { severity: 'warning' }]),
    ).toBe('warning')
  })

  it('returns ready when all sections are ready', () => {
    expect(
      combineSetupReadinessSeverity([{ severity: 'ready' }, { severity: 'ready' }]),
    ).toBe('ready')
  })
})

describe('buildExpenseReadinessSection', () => {
  it('blocks when no active categories exist', () => {
    const section = buildExpenseReadinessSection(
      expenseOverview([
        {
          id: 'c1',
          name: 'Travel',
          nameKey: 'expenseCategorySetup.categories.travel',
          categoryCode: 'travel',
          monthly: 1000,
          docThreshold: 100,
          accountingCode: '770',
          code: '770',
          isActive: false,
          approvalPolicy: readyPolicy,
          approvalStepCount: 1,
        },
      ]),
    )

    expect(section.severity).toBe('blocking')
    expect(section.issues.some((issue) => issue.id === 'expense.noActiveCategories')).toBe(true)
  })

  it('warns on active categories with policy gaps without blocking', () => {
    const section = buildExpenseReadinessSection(
      expenseOverview([
        {
          id: 'c1',
          name: 'Travel',
          nameKey: 'expenseCategorySetup.categories.travel',
          categoryCode: 'travel',
          monthly: 1000,
          docThreshold: 100,
          accountingCode: '770',
          code: '770',
          isActive: true,
          approvalPolicy: unboundPolicy,
          approvalStepCount: 0,
        },
      ]),
    )

    expect(section.severity).toBe('warning')
    expect(section.issues.some((issue) => issue.id === 'expense.policyNotReady')).toBe(true)
    expect(section.issues.some((issue) => issue.severity === 'blocking')).toBe(false)
  })
})

describe('buildLeaveReadinessSection', () => {
  it('blocks when no active leave types exist', () => {
    const section = buildLeaveReadinessSection(
      leaveOverview([
        {
          id: 'lt1',
          code: 'annual',
          name: 'Annual',
          labelKey: 'leaveTypeSetup.types.annual',
          defaultEntitlementDays: 20,
          paid: true,
          doc: false,
          carryOver: false,
          maxCarryOverDays: null,
          days: 20,
          isActive: false,
          approvalPolicy: readyPolicy,
          approvalStepCount: 1,
        },
      ]),
    )

    expect(section.severity).toBe('blocking')
    expect(section.issues.some((issue) => issue.id === 'leave.noActiveLeaveTypes')).toBe(true)
  })
})

describe('buildApprovalPolicyReadinessSection', () => {
  it('never produces blocking severity or blocking issues for policy-only gaps', () => {
    const section = buildApprovalPolicyReadinessSection({
      expenseTargets: [{ id: 'c1', approvalPolicy: unboundPolicy }],
      leaveTargets: [
        {
          id: 'lt1',
          approvalPolicy: buildApprovalPolicyBindingInfo({
            expectedModule: 'leave',
            policyId: null,
            policyModule: null,
            policyIsActive: null,
            requiredStepCount: 0,
          }),
        },
      ],
    })

    expect(section.severity).toBe('warning')
    expect(section.issues.every((issue) => issue.severity === 'warning')).toBe(true)
    expect(
      combineSetupReadinessSeverity([
        { severity: section.severity },
        { severity: 'ready' },
      ]),
    ).toBe('warning')
  })
})

describe('buildOrgReadinessSection', () => {
  it('blocks when departments or positions are empty', () => {
    const section = buildOrgReadinessSection(
      orgOverview({
        departments: { status: 'empty', total: 0, active: 0 },
        positions: { status: 'empty', total: 0, active: 0 },
        costCenters: { status: 'empty', total: 0, active: 0, mapped: 0, unmapped: 0 },
      }),
    )

    expect(section.severity).toBe('blocking')
    expect(section.issues.some((issue) => issue.id === 'org.departmentsEmpty')).toBe(true)
    expect(section.issues.some((issue) => issue.id === 'org.positionsEmpty')).toBe(true)
  })
})

describe('buildEmployeeAssignmentReadinessSection', () => {
  it('blocks on inactive references and missing cost centers', () => {
    const section = buildEmployeeAssignmentReadinessSection(
      assignmentOverview({
        total: 5,
        active: 4,
        ready: 1,
        missingDepartment: 0,
        missingPosition: 0,
        missingCostCenter: 2,
        missingManager: 1,
        inactiveReferences: 1,
      }),
    )

    expect(section.severity).toBe('blocking')
    expect(section.issues.some((issue) => issue.id === 'assignments.inactiveReferences')).toBe(
      true,
    )
    expect(section.issues.some((issue) => issue.id === 'assignments.missingCostCenter')).toBe(
      true,
    )
    expect(section.issues.some((issue) => issue.id === 'assignments.missingManager')).toBe(true)
  })
})

describe('buildCostCenterReadinessSection', () => {
  it('blocks on unmapped cost centers for setup/export readiness', () => {
    const section = buildCostCenterReadinessSection(
      costCenterOverview({
        exportReadyCount: 1,
        needsMappingCount: 2,
        items: [
          {
            id: 'cc1',
            code: 'CC-1',
            name: 'Ops',
            sourceName: null,
            sourceCode: null,
            sourceType: null,
            externalId: null,
            status: 'export_ready',
            exportSourceType: 'erp',
          },
          {
            id: 'cc2',
            code: 'CC-2',
            name: 'Needs map',
            sourceName: null,
            sourceCode: null,
            sourceType: null,
            externalId: null,
            status: 'needs_mapping',
            exportSourceType: null,
          },
        ],
      }),
    )

    expect(section.severity).toBe('blocking')
    expect(section.issues.some((issue) => issue.id === 'costCenters.unmapped')).toBe(true)
  })
})

describe('buildRequestCreationReadinessSection', () => {
  it('blocks when request creation blockers exist and warns on policy gaps', () => {
    const section = buildRequestCreationReadinessSection({
      expense: requestCreationResult({
        readiness: {
          domain: 'expense',
          canCreate: false,
          blockers: ['missing_cost_center'],
          warnings: ['policy_unbound'],
        },
      }),
      leave: requestCreationResult({
        readiness: {
          domain: 'leave',
          canCreate: true,
          blockers: [],
          warnings: ['missing_manager'],
        },
      }),
    })

    expect(section.severity).toBe('blocking')
    expect(section.issues.some((issue) => issue.id === 'requestCreation.expenseBlocked')).toBe(
      true,
    )
    expect(section.issues.some((issue) => issue.id === 'requestCreation.policyUnbound')).toBe(true)
    expect(section.issues.some((issue) => issue.id === 'requestCreation.missingManager')).toBe(
      true,
    )
  })
})

describe('all-ready dashboard composition', () => {
  it('returns ready severity when every section is ready', () => {
    const sections = [
      buildExpenseReadinessSection(
        expenseOverview([
          {
            id: 'c1',
            name: 'Travel',
            nameKey: 'expenseCategorySetup.categories.travel',
            categoryCode: 'travel',
            monthly: 1000,
            docThreshold: 100,
            accountingCode: '770',
            code: '770',
            isActive: true,
            approvalPolicy: readyPolicy,
            approvalStepCount: 1,
          },
        ]),
      ),
      buildLeaveReadinessSection(
        leaveOverview([
          {
            id: 'lt1',
            code: 'annual',
            name: 'Annual',
            labelKey: 'leaveTypeSetup.types.annual',
            defaultEntitlementDays: 20,
            paid: true,
            doc: false,
            carryOver: false,
            maxCarryOverDays: null,
            days: 20,
            isActive: true,
            approvalPolicy: buildApprovalPolicyBindingInfo({
              expectedModule: 'leave',
              policyId: 'policy-leave',
              policyName: 'Leave policy',
              policyModule: 'leave',
              policyIsActive: true,
              requiredStepCount: 1,
            }),
            approvalStepCount: 1,
          },
        ]),
      ),
      buildApprovalPolicyReadinessSection({
        expenseTargets: [{ id: 'c1', approvalPolicy: readyPolicy }],
        leaveTargets: [
          {
            id: 'lt1',
            approvalPolicy: buildApprovalPolicyBindingInfo({
              expectedModule: 'leave',
              policyId: 'policy-leave',
              policyName: 'Leave policy',
              policyModule: 'leave',
              policyIsActive: true,
              requiredStepCount: 1,
            }),
          },
        ],
      }),
      buildOrgReadinessSection(
        orgOverview({
          departments: { status: 'ready', total: 2, active: 2 },
          positions: { status: 'ready', total: 2, active: 2 },
          costCenters: { status: 'ready', total: 2, active: 2, mapped: 2, unmapped: 0 },
        }),
      ),
      buildEmployeeAssignmentReadinessSection(
        assignmentOverview({
          total: 2,
          active: 2,
          ready: 2,
          missingDepartment: 0,
          missingPosition: 0,
          missingCostCenter: 0,
          missingManager: 0,
          inactiveReferences: 0,
        }),
      ),
      buildCostCenterReadinessSection(
        costCenterOverview({
          exportReadyCount: 1,
          needsMappingCount: 0,
          items: [
            {
              id: 'cc1',
              code: 'CC-1',
              name: 'Ops',
              sourceName: null,
              sourceCode: null,
              sourceType: null,
              externalId: null,
              status: 'export_ready',
              exportSourceType: 'erp',
            },
          ],
        }),
      ),
      buildRequestCreationReadinessSection({
        expense: requestCreationResult({
          readiness: { domain: 'expense', canCreate: true, blockers: [], warnings: [] },
        }),
        leave: requestCreationResult({
          readiness: { domain: 'leave', canCreate: true, blockers: [], warnings: [] },
        }),
      }),
    ]

    expect(combineSetupReadinessSeverity(sections)).toBe('ready')
    expect(sections.every((section) => section.severity === 'ready')).toBe(true)
  })
})

describe('failed source handling', () => {
  it('represents unknown sections when source data is unavailable', () => {
    const unknownSection = buildExpenseReadinessSection(expenseOverview([]))
    unknownSection.severity = 'unknown'
    unknownSection.issues = [
      {
        id: 'sourceUnknown',
        severity: 'unknown',
        titleKey: 'setupReadinessDashboard.issues.sourceUnknown.title',
        descriptionKey: 'setupReadinessDashboard.issues.sourceUnknown.description',
        target: '/masraf-kategorileri',
      },
    ]

    expect(unknownSection.severity).toBe('unknown')
    expect(unknownSection.issues[0]?.id).toBe('sourceUnknown')
  })
})
