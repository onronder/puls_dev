import type {
  ApprovalPolicyBindingInfo,
  ApprovalPolicyBindingStatus,
} from '#/lib/data/workflow/policy-binding-readiness'
import { applyExpenseCategoryLifecycleFilter } from '#/lib/data/setup/expense-categories'
import { applyLeaveTypeLifecycleFilter } from '#/lib/data/setup/leave-types'
import { fetchExpenseCategoriesOverview } from '#/lib/data/setup/expense-categories'
import { fetchLeaveTypesOverview } from '#/lib/data/setup/leave-types'
import { fetchExpenseOverview } from '#/lib/data/expense/overview'
import { fetchLeaveOverview } from '#/lib/data/leave/overview'
import { resolveAdapterDataWithMeta } from '#/lib/data/result'
import {
  fetchCurrentEmployeeAssignmentReadiness,
  type EmployeeAssignmentReadinessEmployee,
} from '#/lib/data/setup/employee-assignment-readiness'
import {
  fetchDemoEmployeeAssignmentReadiness,
  fetchDemoExpenseCategoriesOverview,
  fetchDemoExpenseOverview,
  fetchDemoLeaveOverview,
  fetchDemoLeaveTypesOverview,
} from '#/lib/demo/puls-demo-data'

export type RequestCreationDomain = 'expense' | 'leave'

export type RequestCreationBlocker =
  | 'no_active_expense_categories'
  | 'no_active_leave_types'
  | 'invalid_expense_category'
  | 'invalid_leave_type'
  | 'missing_cost_center'
  | 'inactive_assignment_reference'
  | 'assignment_partial'
  | 'unknown'

export type RequestCreationWarning =
  | 'missing_manager'
  | 'missing_cost_center'
  | 'policy_unbound'
  | 'policy_inactive'
  | 'policy_missing_steps'
  | 'policy_module_mismatch'

export type RequestCreationReadiness = {
  domain: RequestCreationDomain
  canCreate: boolean
  blockers: RequestCreationBlocker[]
  warnings: RequestCreationWarning[]
}

export type PolicyTarget = {
  id: string
  approvalPolicy: ApprovalPolicyBindingInfo
}

export type BuildExpenseCreationReadinessInput = {
  activeCategoryCount: number
  assignment: EmployeeAssignmentReadinessEmployee | null
  policyTargets: PolicyTarget[]
  selectedCategoryId?: string | null
}

export type BuildLeaveCreationReadinessInput = {
  activeLeaveTypeCount: number
  assignment: EmployeeAssignmentReadinessEmployee | null
  policyTargets: PolicyTarget[]
  selectedLeaveTypeId?: string | null
}

export type RequestCreationReadinessResult = {
  readiness: RequestCreationReadiness
  assignment: EmployeeAssignmentReadinessEmployee | null
  activeTargetCount: number
  policyReadyCount: number
  policyTargets: PolicyTarget[]
}

const BLOCKER_PRECEDENCE: RequestCreationBlocker[] = [
  'inactive_assignment_reference',
  'assignment_partial',
  'missing_cost_center',
  'invalid_expense_category',
  'invalid_leave_type',
  'no_active_expense_categories',
  'no_active_leave_types',
  'unknown',
]

export function mapPolicyStatusToWarning(
  status: ApprovalPolicyBindingStatus,
): RequestCreationWarning | null {
  switch (status) {
    case 'ready':
      return null
    case 'unbound':
      return 'policy_unbound'
    case 'inactive_policy':
    case 'policy_unavailable':
      return 'policy_inactive'
    case 'missing_required_steps':
      return 'policy_missing_steps'
    case 'module_mismatch':
      return 'policy_module_mismatch'
    default:
      return null
  }
}

function uniqueWarnings(warnings: RequestCreationWarning[]): RequestCreationWarning[] {
  return [...new Set(warnings)]
}

function collectPolicyWarnings(
  policyTargets: PolicyTarget[],
  selectedTargetId?: string | null,
): RequestCreationWarning[] {
  const warnings: RequestCreationWarning[] = []

  for (const target of policyTargets) {
    const warning = mapPolicyStatusToWarning(target.approvalPolicy.status)
    if (warning) warnings.push(warning)
  }

  if (selectedTargetId) {
    const selected = policyTargets.find((target) => target.id === selectedTargetId)
    if (selected) {
      const warning = mapPolicyStatusToWarning(selected.approvalPolicy.status)
      if (warning && !warnings.includes(warning)) {
        warnings.push(warning)
      }
    }
  }

  return uniqueWarnings(warnings)
}

function applyAssignmentReadiness(input: {
  domain: RequestCreationDomain
  assignment: EmployeeAssignmentReadinessEmployee | null
  blockers: RequestCreationBlocker[]
  warnings: RequestCreationWarning[]
}) {
  const { assignment, domain, blockers, warnings } = input

  if (!assignment) {
    blockers.push('unknown')
    return
  }

  if (!assignment.isActive || assignment.readiness.status === 'partial') {
    blockers.push('assignment_partial')
    return
  }

  if (assignment.readiness.status === 'inactive_reference') {
    blockers.push('inactive_assignment_reference')
    return
  }

  const { flags } = assignment.readiness

  if (!flags.hasCostCenter) {
    if (domain === 'expense') {
      blockers.push('missing_cost_center')
    } else {
      warnings.push('missing_cost_center')
    }
  }

  if (!flags.hasManager) {
    warnings.push('missing_manager')
  }
}

export function buildExpenseCreationReadiness(
  input: BuildExpenseCreationReadinessInput,
): RequestCreationReadiness {
  const blockers: RequestCreationBlocker[] = []
  const warnings: RequestCreationWarning[] = []

  if (input.activeCategoryCount === 0) {
    blockers.push('no_active_expense_categories')
  }
  if (
    input.selectedCategoryId &&
    input.activeCategoryCount > 0 &&
    !input.policyTargets.some((target) => target.id === input.selectedCategoryId)
  ) {
    blockers.push('invalid_expense_category')
  }

  applyAssignmentReadiness({
    domain: 'expense',
    assignment: input.assignment,
    blockers,
    warnings,
  })

  const policyReadyCount = input.policyTargets.filter(
    (target) => target.approvalPolicy.status === 'ready',
  ).length

  if (input.activeCategoryCount > 0 && policyReadyCount === 0) {
    warnings.push(...collectPolicyWarnings(input.policyTargets, input.selectedCategoryId))
  } else if (input.selectedCategoryId) {
    warnings.push(...collectPolicyWarnings(input.policyTargets, input.selectedCategoryId))
  }

  return {
    domain: 'expense',
    canCreate: blockers.length === 0,
    blockers,
    warnings: uniqueWarnings(warnings),
  }
}

export function buildLeaveCreationReadiness(
  input: BuildLeaveCreationReadinessInput,
): RequestCreationReadiness {
  const blockers: RequestCreationBlocker[] = []
  const warnings: RequestCreationWarning[] = []

  if (input.activeLeaveTypeCount === 0) {
    blockers.push('no_active_leave_types')
  }
  if (
    input.selectedLeaveTypeId &&
    input.activeLeaveTypeCount > 0 &&
    !input.policyTargets.some((target) => target.id === input.selectedLeaveTypeId)
  ) {
    blockers.push('invalid_leave_type')
  }

  applyAssignmentReadiness({
    domain: 'leave',
    assignment: input.assignment,
    blockers,
    warnings,
  })

  const policyReadyCount = input.policyTargets.filter(
    (target) => target.approvalPolicy.status === 'ready',
  ).length

  if (input.activeLeaveTypeCount > 0 && policyReadyCount === 0) {
    warnings.push(...collectPolicyWarnings(input.policyTargets, input.selectedLeaveTypeId))
  } else if (input.selectedLeaveTypeId) {
    warnings.push(...collectPolicyWarnings(input.policyTargets, input.selectedLeaveTypeId))
  }

  return {
    domain: 'leave',
    canCreate: blockers.length === 0,
    blockers,
    warnings: uniqueWarnings(warnings),
  }
}

export function getPrimaryRequestCreationBlocker(
  readiness: RequestCreationReadiness,
): RequestCreationBlocker | null {
  for (const blocker of BLOCKER_PRECEDENCE) {
    if (readiness.blockers.includes(blocker)) {
      return blocker
    }
  }
  return readiness.blockers[0] ?? null
}

async function fetchDemoRequestCreationReadiness(
  domain: RequestCreationDomain,
): Promise<RequestCreationReadinessResult> {
  const assignmentOverview = await fetchDemoEmployeeAssignmentReadiness()
  const assignment =
    assignmentOverview.employees.find((employee) => employee.id === 'demo-e-ready') ?? null

  if (domain === 'expense') {
    const [overview, setupOverview] = await Promise.all([
      fetchDemoExpenseOverview(),
      fetchDemoExpenseCategoriesOverview(),
    ])
    const activeTargets = applyExpenseCategoryLifecycleFilter(setupOverview.categories, 'active')
    const policyTargets: PolicyTarget[] = activeTargets.map((target) => ({
      id: target.id,
      approvalPolicy: target.approvalPolicy,
    }))
    const policyReadyCount = policyTargets.filter(
      (target) => target.approvalPolicy.status === 'ready',
    ).length
    const readiness = buildExpenseCreationReadiness({
      activeCategoryCount: overview.categoryLimits.length,
      assignment,
      policyTargets,
    })
    return {
      readiness,
      assignment,
      activeTargetCount: overview.categoryLimits.length,
      policyReadyCount,
      policyTargets,
    }
  }

  const [overview, setupOverview] = await Promise.all([
    fetchDemoLeaveOverview(),
    fetchDemoLeaveTypesOverview(),
  ])
  const activeTargets = applyLeaveTypeLifecycleFilter(setupOverview.leaveTypes, 'active')
  const policyTargets: PolicyTarget[] = activeTargets.map((target) => ({
    id: target.id,
    approvalPolicy: target.approvalPolicy,
  }))
  const policyReadyCount = policyTargets.filter(
    (target) => target.approvalPolicy.status === 'ready',
  ).length
  const readiness = buildLeaveCreationReadiness({
    activeLeaveTypeCount: overview.leaveTypes.length,
    assignment,
    policyTargets,
  })
  return {
    readiness,
    assignment,
    activeTargetCount: overview.leaveTypes.length,
    policyReadyCount,
    policyTargets,
  }
}

export function getRequestCreationBlockerI18nKey(
  blocker: RequestCreationBlocker,
  domain: RequestCreationDomain,
): string {
  if (blocker === 'assignment_partial') {
    return 'requestCreationReadiness.common.assignmentPartial'
  }
  if (blocker === 'no_active_expense_categories') {
    return 'requestCreationReadiness.expense.noActiveCategories'
  }
  if (blocker === 'no_active_leave_types') {
    return 'requestCreationReadiness.leave.noActiveLeaveTypes'
  }
  if (blocker === 'invalid_expense_category') {
    return 'requestCreationReadiness.expense.invalidCategory'
  }
  if (blocker === 'invalid_leave_type') {
    return 'requestCreationReadiness.leave.invalidLeaveType'
  }
  if (blocker === 'inactive_assignment_reference') {
    return 'requestCreationReadiness.common.inactiveAssignmentReference'
  }
  if (blocker === 'missing_cost_center' && domain === 'expense') {
    return 'requestCreationReadiness.common.missingCostCenter'
  }
  return `requestCreationReadiness.blockers.${blocker}`
}

export function getRequestCreationWarningI18nKey(warning: RequestCreationWarning): string {
  switch (warning) {
    case 'missing_manager':
      return 'requestCreationReadiness.common.missingManager'
    case 'missing_cost_center':
      return 'requestCreationReadiness.common.missingCostCenterWarn'
    case 'policy_unbound':
      return 'requestCreationReadiness.common.policyUnbound'
    case 'policy_inactive':
      return 'requestCreationReadiness.common.policyInactive'
    case 'policy_missing_steps':
      return 'requestCreationReadiness.common.policyMissingSteps'
    case 'policy_module_mismatch':
      return 'requestCreationReadiness.common.policyModuleMismatch'
    default:
      return 'requestCreationReadiness.common.policyNotReady'
  }
}

async function fetchRealRequestCreationReadiness(
  userId: string,
  domain: RequestCreationDomain,
): Promise<RequestCreationReadinessResult> {
  const assignment = await fetchCurrentEmployeeAssignmentReadiness(userId)

  if (domain === 'expense') {
    const [overview, setupOverview] = await Promise.all([
      fetchExpenseOverview(userId),
      fetchExpenseCategoriesOverview(userId),
    ])
    const activeTargets = applyExpenseCategoryLifecycleFilter(setupOverview.categories, 'active')
    const policyTargets: PolicyTarget[] = activeTargets.map((target) => ({
      id: target.id,
      approvalPolicy: target.approvalPolicy,
    }))
    const policyReadyCount = policyTargets.filter(
      (target) => target.approvalPolicy.status === 'ready',
    ).length
    const readiness = buildExpenseCreationReadiness({
      activeCategoryCount: overview.categoryLimits.length,
      assignment,
      policyTargets,
    })
    return {
      readiness,
      assignment,
      activeTargetCount: overview.categoryLimits.length,
      policyReadyCount,
      policyTargets,
    }
  }

  const [overview, setupOverview] = await Promise.all([
    fetchLeaveOverview(userId),
    fetchLeaveTypesOverview(userId),
  ])
  const activeTargets = applyLeaveTypeLifecycleFilter(setupOverview.leaveTypes, 'active')
  const policyTargets: PolicyTarget[] = activeTargets.map((target) => ({
    id: target.id,
    approvalPolicy: target.approvalPolicy,
  }))
  const policyReadyCount = policyTargets.filter(
    (target) => target.approvalPolicy.status === 'ready',
  ).length
  const readiness = buildLeaveCreationReadiness({
    activeLeaveTypeCount: overview.leaveTypes.length,
    assignment,
    policyTargets,
  })
  return {
    readiness,
    assignment,
    activeTargetCount: overview.leaveTypes.length,
    policyReadyCount,
    policyTargets,
  }
}

export function fetchRequestCreationReadinessWithMeta(
  userId: string,
  domain: RequestCreationDomain,
) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchRequestCreationReadiness',
    fetchReal: () => fetchRealRequestCreationReadiness(userId, domain),
    fetchDemo: () => fetchDemoRequestCreationReadiness(domain),
    isEmpty: () => false,
  })
}

export async function fetchRequestCreationReadiness(
  userId: string,
  domain: RequestCreationDomain,
): Promise<RequestCreationReadinessResult & { source: 'real' | 'demo' }> {
  const result = await fetchRequestCreationReadinessWithMeta(userId, domain)
  if (result.status === 'error' && result.error) {
    throw result.error
  }
  return {
    ...result.data,
    source: result.source,
  }
}
