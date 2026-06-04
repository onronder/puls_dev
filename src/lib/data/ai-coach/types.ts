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
  | 'connector_runtime'
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

export type AiCoachRuntimeEvidenceActionId =
  | 'explain'
  | 'summarize'
  | 'detect_gap'
  | 'recommend_next_step'
  | 'prepare_review'
  | 'source_disclosure'

export type AiCoachRuntimeEvidenceForbiddenActionId =
  | 'start_connector_job'
  | 'read_credential'
  | 'apply_import'
  | 'write_to_source'
  | 'mutate_workflow'

export type AiCoachRuntimeEvidenceSignal = {
  id: string
  labelKey: string
  value: number | string | boolean
  sourceKey: string
  disclosureKey: string
  status: AiCoachContextReadinessStatus
}

export type AiCoachRuntimeEvidenceContract = {
  sourceDisclosureRequired: true
  signals: AiCoachRuntimeEvidenceSignal[]
  allowedSuggestionActions: AiCoachRuntimeEvidenceActionId[]
  forbiddenActions: AiCoachRuntimeEvidenceForbiddenActionId[]
}

export type AiCoachOverview = {
  capabilities: AiCoachCapability[]
  readiness: AiCoachReadinessItem[]
  contextDomains: AiCoachContextDomain[]
  guardrails: AiCoachGuardrail[]
  runtimeEvidence: AiCoachRuntimeEvidenceContract
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
  connectorConnectionCount: number | null
  connectorRuntimeJobCount: number | null
  connectorRuntimeFailedJobCount: number | null
  connectorRuntimeDeadLetterJobCount: number | null
  connectorJobEventCount: number | null
  connectorCredentialVerifiedCount: number | null
  connectorCredentialMissingCount: number | null
  connectorImportPreviewBatchCount: number | null
  connectorSafeActivityCount: number | null
  leaveOverviewPresent: boolean
  expenseOverviewPresent: boolean
  performanceOverviewPresent: boolean
}
