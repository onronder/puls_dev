export type AiCoachReadinessStatus = 'done' | 'pending'

export type AiCoachCapability = {
  id: string
  titleKey: string
  descKey: string
}

export type AiCoachReadinessItem = {
  id: string
  labelKey: string
  status: AiCoachReadinessStatus
}

export type AiCoachContextReadinessStatus = 'ready' | 'partial' | 'blocked'

export type AiCoachContextDomainId =
  | 'setup'
  | 'employee_quality'
  | 'leave'
  | 'expense'
  | 'performance'
  | 'contracts'
  | 'dashboard'
  | 'profile'

export type AiCoachContextDomain = {
  id: AiCoachContextDomainId
  titleKey: string
  descriptionKey: string
  status: AiCoachContextReadinessStatus
  sourcePosture: 'real' | 'demo' | 'not_applicable'
  evidence: {
    labelKey: string
    value: number | string | boolean
  }[]
  guardrailKey: string
  route: string
}

export type AiCoachGuardrail = {
  id: string
  labelKey: string
  status: 'enforced' | 'pending'
}

export type AiCoachProductPosture = 'teaser_context_ready' | 'teaser_context_partial'

export type AiCoachOverview = {
  capabilities: AiCoachCapability[]
  readiness: AiCoachReadinessItem[]
  contextDomains: AiCoachContextDomain[]
  guardrails: AiCoachGuardrail[]
  productPosture: AiCoachProductPosture
}

export type AiCoachContextSnapshot = {
  tenantPresent: boolean
  employeeId: string | null
  employeeName: string | null
  setupReadinessPct: number | null
  setupQueryOk: boolean
  departmentCount: number | null
  positionCount: number | null
  employeeCount: number | null
  reportingLineCount: number | null
  leaveTypeCount: number | null
  leaveBalanceCount: number | null
  leaveRequestCount: number | null
  expenseCategoryCount: number | null
  expenseClaimCount: number | null
  performanceCycleCount: number | null
  competencyTemplateCount: number | null
  performanceScoreCount: number | null
  competencyEvaluationCount: number | null
  contractCount: number | null
  contractsOverviewPresent: boolean
  dashboardOverviewPresent: boolean
  sourceNamespaceCount: number | null
  inactiveErpConnectionPresent: boolean
  leaveOverviewPresent: boolean
  expenseOverviewPresent: boolean
  performanceOverviewPresent: boolean
}
