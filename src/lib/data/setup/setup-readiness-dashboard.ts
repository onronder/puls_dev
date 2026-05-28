import { applyExpenseCategoryLifecycleFilter } from '#/lib/data/setup/expense-categories'
import { fetchExpenseCategoriesOverview, type ExpenseCategoriesOverview } from '#/lib/data/setup/expense-categories'
import { applyLeaveTypeLifecycleFilter } from '#/lib/data/setup/leave-types'
import { fetchLeaveTypesOverview, type LeaveTypesOverview } from '#/lib/data/setup/leave-types'
import {
  fetchCostCenterReadinessOverview,
  type CostCenterReadinessOverview,
} from '#/lib/data/setup/cost-center-readiness'
import {
  fetchEmployeeAssignmentReadiness,
  type EmployeeAssignmentReadinessOverview,
} from '#/lib/data/setup/employee-assignment-readiness'
import {
  fetchOrgSetupReadiness,
  type OrgSetupReadinessOverview,
  type OrgSetupReadinessStatus,
} from '#/lib/data/setup/org-setup-readiness'
import {
  fetchRequestCreationReadiness,
  type PolicyTarget,
  type RequestCreationBlocker,
  type RequestCreationDomain,
  type RequestCreationReadinessResult,
  type RequestCreationWarning,
} from '#/lib/data/setup/request-creation-readiness'

export type SetupReadinessSeverity = 'ready' | 'warning' | 'blocking' | 'unknown'

export type SetupReadinessActionTarget =
  | '/masraf-kategorileri'
  | '/izin-tanimlari'
  | '/departmanlar'
  | '/pozisyonlar'
  | '/calisanlar'
  | '/sirket-kurulum'

export type SetupReadinessSectionId =
  | 'expense'
  | 'leave'
  | 'approvalPolicies'
  | 'org'
  | 'assignments'
  | 'costCenters'
  | 'requestCreation'

export type SetupReadinessIssue = {
  id: string
  severity: SetupReadinessSeverity
  titleKey: string
  descriptionKey: string
  count?: number
  target: SetupReadinessActionTarget
}

export type SetupReadinessSection = {
  id: SetupReadinessSectionId
  titleKey: string
  severity: SetupReadinessSeverity
  readyCount: number
  totalCount: number
  issues: SetupReadinessIssue[]
  target: SetupReadinessActionTarget
}

export type SetupReadinessDashboard = {
  severity: SetupReadinessSeverity
  generatedAt: string
  sections: SetupReadinessSection[]
}

const SEVERITY_RANK: Record<SetupReadinessSeverity, number> = {
  ready: 1,
  warning: 2,
  unknown: 3,
  blocking: 4,
}

function issueKeys(id: string): Pick<SetupReadinessIssue, 'titleKey' | 'descriptionKey'> {
  return {
    titleKey: `setupReadinessDashboard.issues.${id}.title`,
    descriptionKey: `setupReadinessDashboard.issues.${id}.description`,
  }
}

function buildIssue(
  id: string,
  severity: SetupReadinessSeverity,
  target: SetupReadinessActionTarget,
  count?: number,
): SetupReadinessIssue {
  return {
    id,
    severity,
    target,
    count,
    ...issueKeys(id),
  }
}

export function rankSetupReadinessSeverity(
  a: SetupReadinessSeverity,
  b: SetupReadinessSeverity,
): number {
  return SEVERITY_RANK[a] - SEVERITY_RANK[b]
}

export function maxSetupReadinessSeverity(
  severities: SetupReadinessSeverity[],
): SetupReadinessSeverity {
  if (severities.length === 0) return 'ready'
  return severities.reduce((max, current) =>
    SEVERITY_RANK[current] > SEVERITY_RANK[max] ? current : max,
  )
}

export function combineSetupReadinessSeverity(
  sections: Pick<SetupReadinessSection, 'severity'>[],
): SetupReadinessSeverity {
  return maxSetupReadinessSeverity(sections.map((section) => section.severity))
}

function sectionSeverityFromIssues(
  issues: SetupReadinessIssue[],
  cap?: SetupReadinessSeverity,
): SetupReadinessSeverity {
  const severity = maxSetupReadinessSeverity(issues.map((issue) => issue.severity))
  if (cap && SEVERITY_RANK[severity] > SEVERITY_RANK[cap]) {
    return cap
  }
  return severity
}

function toPolicyTargetsFromExpense(overview: ExpenseCategoriesOverview): PolicyTarget[] {
  return applyExpenseCategoryLifecycleFilter(overview.categories, 'active').map((category) => ({
    id: category.id,
    approvalPolicy: category.approvalPolicy,
  }))
}

function toPolicyTargetsFromLeave(overview: LeaveTypesOverview): PolicyTarget[] {
  return applyLeaveTypeLifecycleFilter(overview.leaveTypes, 'active').map((leaveType) => ({
    id: leaveType.id,
    approvalPolicy: leaveType.approvalPolicy,
  }))
}

function orgDomainIsReady(status: OrgSetupReadinessStatus): boolean {
  return status === 'ready'
}

export function buildExpenseReadinessSection(
  overview: ExpenseCategoriesOverview,
): SetupReadinessSection {
  const active = applyExpenseCategoryLifecycleFilter(overview.categories, 'active')
  const inactiveCount = overview.categories.length - active.length
  const policyReadyCount = active.filter(
    (category) => category.approvalPolicy.status === 'ready',
  ).length
  const issues: SetupReadinessIssue[] = []

  if (active.length === 0) {
    issues.push(
      buildIssue('expense.noActiveCategories', 'blocking', '/masraf-kategorileri'),
    )
  }

  if (inactiveCount > 0) {
    issues.push(
      buildIssue('expense.inactiveCategories', 'warning', '/masraf-kategorileri', inactiveCount),
    )
  }

  const policyNotReadyCount = active.filter(
    (category) => category.approvalPolicy.status !== 'ready',
  ).length
  if (policyNotReadyCount > 0) {
    issues.push(
      buildIssue('expense.policyNotReady', 'warning', '/masraf-kategorileri', policyNotReadyCount),
    )
  }

  return {
    id: 'expense',
    titleKey: 'setupReadinessDashboard.sections.expense',
    severity: sectionSeverityFromIssues(issues),
    readyCount: policyReadyCount,
    totalCount: active.length,
    issues,
    target: '/masraf-kategorileri',
  }
}

export function buildLeaveReadinessSection(overview: LeaveTypesOverview): SetupReadinessSection {
  const active = applyLeaveTypeLifecycleFilter(overview.leaveTypes, 'active')
  const inactiveCount = overview.leaveTypes.length - active.length
  const policyReadyCount = active.filter(
    (leaveType) => leaveType.approvalPolicy.status === 'ready',
  ).length
  const issues: SetupReadinessIssue[] = []

  if (active.length === 0) {
    issues.push(buildIssue('leave.noActiveLeaveTypes', 'blocking', '/izin-tanimlari'))
  }

  if (inactiveCount > 0) {
    issues.push(
      buildIssue('leave.inactiveLeaveTypes', 'warning', '/izin-tanimlari', inactiveCount),
    )
  }

  const policyNotReadyCount = active.filter(
    (leaveType) => leaveType.approvalPolicy.status !== 'ready',
  ).length
  if (policyNotReadyCount > 0) {
    issues.push(
      buildIssue('leave.policyNotReady', 'warning', '/izin-tanimlari', policyNotReadyCount),
    )
  }

  return {
    id: 'leave',
    titleKey: 'setupReadinessDashboard.sections.leave',
    severity: sectionSeverityFromIssues(issues),
    readyCount: policyReadyCount,
    totalCount: active.length,
    issues,
    target: '/izin-tanimlari',
  }
}

export function buildApprovalPolicyReadinessSection(input: {
  expenseTargets: PolicyTarget[]
  leaveTargets: PolicyTarget[]
}): SetupReadinessSection {
  const allTargets = [...input.expenseTargets, ...input.leaveTargets]
  const notReadyCount = allTargets.filter(
    (target) => target.approvalPolicy.status !== 'ready',
  ).length
  const issues: SetupReadinessIssue[] = []

  if (notReadyCount > 0) {
    issues.push(
      buildIssue('approvalPolicies.notReady', 'warning', '/masraf-kategorileri', notReadyCount),
    )
  }

  return {
    id: 'approvalPolicies',
    titleKey: 'setupReadinessDashboard.sections.approvalPolicies',
    severity: sectionSeverityFromIssues(issues, 'warning'),
    readyCount: allTargets.length - notReadyCount,
    totalCount: allTargets.length,
    issues,
    target: '/masraf-kategorileri',
  }
}

export function buildOrgReadinessSection(
  overview: OrgSetupReadinessOverview,
): SetupReadinessSection {
  const { departments, positions, costCenters } = overview.summary
  const issues: SetupReadinessIssue[] = []

  if (departments.status === 'empty') {
    issues.push(buildIssue('org.departmentsEmpty', 'blocking', '/departmanlar'))
  } else if (departments.status === 'partial' || departments.status === 'demo_only') {
    issues.push(
      buildIssue('org.departmentsPartial', 'warning', '/departmanlar', departments.active),
    )
  }

  if (positions.status === 'empty') {
    issues.push(buildIssue('org.positionsEmpty', 'blocking', '/pozisyonlar'))
  } else if (positions.status === 'partial' || positions.status === 'demo_only') {
    issues.push(buildIssue('org.positionsPartial', 'warning', '/pozisyonlar', positions.active))
  }

  if (costCenters.status === 'unmapped') {
    issues.push(
      buildIssue(
        'org.costCentersUnmapped',
        'warning',
        '/masraf-kategorileri',
        costCenters.unmapped ?? 0,
      ),
    )
  } else if (costCenters.status === 'empty' || costCenters.status === 'demo_only') {
    issues.push(buildIssue('org.costCentersEmpty', 'warning', '/masraf-kategorileri'))
  }

  const readyCount = [
    orgDomainIsReady(departments.status),
    orgDomainIsReady(positions.status),
    orgDomainIsReady(costCenters.status),
  ].filter(Boolean).length

  return {
    id: 'org',
    titleKey: 'setupReadinessDashboard.sections.org',
    severity: sectionSeverityFromIssues(issues),
    readyCount,
    totalCount: 3,
    issues,
    target: '/departmanlar',
  }
}

export function buildEmployeeAssignmentReadinessSection(
  overview: EmployeeAssignmentReadinessOverview,
): SetupReadinessSection {
  const { summary } = overview
  const issues: SetupReadinessIssue[] = []

  if (summary.inactiveReferences > 0) {
    issues.push(
      buildIssue(
        'assignments.inactiveReferences',
        'blocking',
        '/calisanlar',
        summary.inactiveReferences,
      ),
    )
  }

  if (summary.missingCostCenter > 0) {
    issues.push(
      buildIssue(
        'assignments.missingCostCenter',
        'blocking',
        '/calisanlar',
        summary.missingCostCenter,
      ),
    )
  }

  if (summary.missingManager > 0) {
    issues.push(
      buildIssue(
        'assignments.missingManager',
        'warning',
        '/calisanlar',
        summary.missingManager,
      ),
    )
  }

  if (summary.missingDepartment > 0) {
    issues.push(
      buildIssue(
        'assignments.missingDepartment',
        'warning',
        '/calisanlar',
        summary.missingDepartment,
      ),
    )
  }

  if (summary.missingPosition > 0) {
    issues.push(
      buildIssue(
        'assignments.missingPosition',
        'warning',
        '/calisanlar',
        summary.missingPosition,
      ),
    )
  }

  return {
    id: 'assignments',
    titleKey: 'setupReadinessDashboard.sections.assignments',
    severity: sectionSeverityFromIssues(issues),
    readyCount: summary.ready,
    totalCount: summary.active,
    issues,
    target: '/calisanlar',
  }
}

export function buildCostCenterReadinessSection(
  overview: CostCenterReadinessOverview,
): SetupReadinessSection {
  const issues: SetupReadinessIssue[] = []

  if (overview.needsMappingCount > 0) {
    issues.push(
      buildIssue(
        'costCenters.unmapped',
        'blocking',
        '/masraf-kategorileri',
        overview.needsMappingCount,
      ),
    )
  }

  if (overview.routingWarnings.length > 0) {
    issues.push(
      buildIssue(
        'costCenters.routingWarnings',
        'warning',
        '/masraf-kategorileri',
        overview.routingWarnings.length,
      ),
    )
  }

  return {
    id: 'costCenters',
    titleKey: 'setupReadinessDashboard.sections.costCenters',
    severity: sectionSeverityFromIssues(issues),
    readyCount: overview.exportReadyCount,
    totalCount: overview.items.length,
    issues,
    target: '/masraf-kategorileri',
  }
}

function requestCreationBlockerTarget(
  blocker: RequestCreationBlocker,
  domain: RequestCreationDomain,
): SetupReadinessActionTarget {
  switch (blocker) {
    case 'no_active_expense_categories':
      return '/masraf-kategorileri'
    case 'no_active_leave_types':
      return '/izin-tanimlari'
    case 'missing_cost_center':
    case 'inactive_assignment_reference':
    case 'assignment_partial':
      return '/calisanlar'
    default:
      return domain === 'expense' ? '/masraf-kategorileri' : '/izin-tanimlari'
  }
}

function requestCreationWarningIssueId(warning: RequestCreationWarning): string {
  switch (warning) {
    case 'missing_manager':
      return 'requestCreation.missingManager'
    case 'missing_cost_center':
      return 'requestCreation.missingCostCenter'
    case 'policy_unbound':
      return 'requestCreation.policyUnbound'
    case 'policy_inactive':
      return 'requestCreation.policyInactive'
    case 'policy_missing_steps':
      return 'requestCreation.policyMissingSteps'
    case 'policy_module_mismatch':
      return 'requestCreation.policyModuleMismatch'
    default:
      return 'requestCreation.policyNotReady'
  }
}

function requestCreationWarningTarget(
  warning: RequestCreationWarning,
  domain: RequestCreationDomain,
): SetupReadinessActionTarget {
  if (warning.startsWith('policy_')) {
    return domain === 'expense' ? '/masraf-kategorileri' : '/izin-tanimlari'
  }
  if (warning === 'missing_manager' || warning === 'missing_cost_center') {
    return '/calisanlar'
  }
  return '/sirket-kurulum'
}

export function buildRequestCreationReadinessSection(input: {
  expense: RequestCreationReadinessResult
  leave: RequestCreationReadinessResult
}): SetupReadinessSection {
  const issues: SetupReadinessIssue[] = []
  const seenWarningIds = new Set<string>()

  if (input.expense.readiness.blockers.length > 0) {
    issues.push(
      buildIssue(
        'requestCreation.expenseBlocked',
        'blocking',
        requestCreationBlockerTarget(input.expense.readiness.blockers[0]!, 'expense'),
        input.expense.readiness.blockers.length,
      ),
    )
  }

  if (input.leave.readiness.blockers.length > 0) {
    issues.push(
      buildIssue(
        'requestCreation.leaveBlocked',
        'blocking',
        requestCreationBlockerTarget(input.leave.readiness.blockers[0]!, 'leave'),
        input.leave.readiness.blockers.length,
      ),
    )
  }

  for (const result of [input.expense, input.leave]) {
    for (const warning of result.readiness.warnings) {
      const id = requestCreationWarningIssueId(warning)
      if (seenWarningIds.has(id)) continue
      seenWarningIds.add(id)
      issues.push(
        buildIssue(
          id,
          'warning',
          requestCreationWarningTarget(warning, result.readiness.domain),
        ),
      )
    }
  }

  const readyCount = [input.expense, input.leave].filter(
    (result) => result.readiness.canCreate,
  ).length

  return {
    id: 'requestCreation',
    titleKey: 'setupReadinessDashboard.sections.requestCreation',
    severity: sectionSeverityFromIssues(issues),
    readyCount,
    totalCount: 2,
    issues,
    target: '/sirket-kurulum',
  }
}

function buildUnknownSection(
  id: SetupReadinessSectionId,
  target: SetupReadinessActionTarget,
): SetupReadinessSection {
  return {
    id,
    titleKey: `setupReadinessDashboard.sections.${id}`,
    severity: 'unknown',
    readyCount: 0,
    totalCount: 0,
    issues: [buildIssue('sourceUnknown', 'unknown', target)],
    target,
  }
}

export async function fetchSetupReadinessDashboard(
  userId: string,
): Promise<SetupReadinessDashboard> {
  const [
    expenseResult,
    leaveResult,
    costCentersResult,
    orgResult,
    assignmentsResult,
    expenseCreationResult,
    leaveCreationResult,
  ] = await Promise.allSettled([
    fetchExpenseCategoriesOverview(userId),
    fetchLeaveTypesOverview(userId),
    fetchCostCenterReadinessOverview(userId),
    fetchOrgSetupReadiness(userId),
    fetchEmployeeAssignmentReadiness(userId),
    fetchRequestCreationReadiness(userId, 'expense'),
    fetchRequestCreationReadiness(userId, 'leave'),
  ])

  const sections: SetupReadinessSection[] = []

  let expenseOverview: ExpenseCategoriesOverview | null = null
  if (expenseResult.status === 'fulfilled') {
    expenseOverview = expenseResult.value
    sections.push(buildExpenseReadinessSection(expenseOverview))
  } else {
    sections.push(buildUnknownSection('expense', '/masraf-kategorileri'))
  }

  let leaveOverview: LeaveTypesOverview | null = null
  if (leaveResult.status === 'fulfilled') {
    leaveOverview = leaveResult.value
    sections.push(buildLeaveReadinessSection(leaveOverview))
  } else {
    sections.push(buildUnknownSection('leave', '/izin-tanimlari'))
  }

  if (expenseOverview || leaveOverview) {
    sections.push(
      buildApprovalPolicyReadinessSection({
        expenseTargets: expenseOverview ? toPolicyTargetsFromExpense(expenseOverview) : [],
        leaveTargets: leaveOverview ? toPolicyTargetsFromLeave(leaveOverview) : [],
      }),
    )
  } else {
    sections.push(buildUnknownSection('approvalPolicies', '/masraf-kategorileri'))
  }

  if (orgResult.status === 'fulfilled') {
    sections.push(buildOrgReadinessSection(orgResult.value))
  } else {
    sections.push(buildUnknownSection('org', '/departmanlar'))
  }

  if (assignmentsResult.status === 'fulfilled') {
    sections.push(buildEmployeeAssignmentReadinessSection(assignmentsResult.value))
  } else {
    sections.push(buildUnknownSection('assignments', '/calisanlar'))
  }

  if (costCentersResult.status === 'fulfilled') {
    sections.push(buildCostCenterReadinessSection(costCentersResult.value))
  } else {
    sections.push(buildUnknownSection('costCenters', '/masraf-kategorileri'))
  }

  if (expenseCreationResult.status === 'fulfilled' && leaveCreationResult.status === 'fulfilled') {
    sections.push(
      buildRequestCreationReadinessSection({
        expense: expenseCreationResult.value,
        leave: leaveCreationResult.value,
      }),
    )
  } else {
    sections.push(buildUnknownSection('requestCreation', '/sirket-kurulum'))
  }

  return {
    severity: combineSetupReadinessSeverity(sections),
    generatedAt: new Date().toISOString(),
    sections,
  }
}
