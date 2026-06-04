import { fetchDemoAiCoachOverview } from '#/lib/demo/puls-demo-data'

import type {
  AiCoachCapability,
  AiCoachContextDomain,
  AiCoachContextDomainId,
  AiCoachContextReadinessStatus,
  AiCoachContextSnapshot,
  AiCoachGuardrail,
  AiCoachOverview,
  AiCoachProductPosture,
  AiCoachReadinessItem,
  AiCoachRuntimeEvidenceActionId,
  AiCoachRuntimeEvidenceContract,
  AiCoachRuntimeEvidenceForbiddenActionId,
  AiCoachRuntimeEvidenceSignal,
} from '#/lib/data/ai-coach/types'

const QUERY_UNAVAILABLE = 'unavailable'

export const DEFAULT_CAPABILITIES: AiCoachCapability[] = [
  {
    id: 'a1',
    titleKey: 'aiCoachSetup.capabilities.leavePlan.title',
    descKey: 'aiCoachSetup.capabilities.leavePlan.desc',
  },
  {
    id: 'a2',
    titleKey: 'aiCoachSetup.capabilities.expensePolicy.title',
    descKey: 'aiCoachSetup.capabilities.expensePolicy.desc',
  },
  {
    id: 'a3',
    titleKey: 'aiCoachSetup.capabilities.performanceReminders.title',
    descKey: 'aiCoachSetup.capabilities.performanceReminders.desc',
  },
  {
    id: 'a4',
    titleKey: 'aiCoachSetup.capabilities.careerDevelopment.title',
    descKey: 'aiCoachSetup.capabilities.careerDevelopment.desc',
  },
]

export function buildDefaultGuardrails(): AiCoachGuardrail[] {
  return [
    { id: 'g1', labelKey: 'aiCoachSetup.guardrails.dbBacked.label', status: 'enforced' },
    { id: 'g2', labelKey: 'aiCoachSetup.guardrails.tenantScoped.label', status: 'enforced' },
    { id: 'g3', labelKey: 'aiCoachSetup.guardrails.humanInLoop.label', status: 'enforced' },
    { id: 'g4', labelKey: 'aiCoachSetup.guardrails.noAutonomousMutations.label', status: 'enforced' },
    { id: 'g5', labelKey: 'aiCoachSetup.guardrails.noAutoApprovals.label', status: 'enforced' },
    { id: 'g6', labelKey: 'aiCoachSetup.guardrails.noErpWrites.label', status: 'enforced' },
    { id: 'g7', labelKey: 'aiCoachSetup.guardrails.noVaultSeed.label', status: 'enforced' },
    { id: 'g8', labelKey: 'aiCoachSetup.guardrails.sourceDisclosure.label', status: 'enforced' },
    { id: 'g9', labelKey: 'aiCoachSetup.guardrails.noCredentialRead.label', status: 'enforced' },
  ]
}

function unavailableEvidence(): { labelKey: string; value: string } {
  return {
    labelKey: 'aiCoachSetup.contextDomains.evidence.queryStatus',
    value: QUERY_UNAVAILABLE,
  }
}

function countEvidence(
  labelKey: string,
  value: number | null,
  queryOk: boolean,
): { labelKey: string; value: number | string } {
  if (!queryOk || value === null) {
    return unavailableEvidence()
  }
  return { labelKey, value }
}

function deriveSetupStatus(snapshot: AiCoachContextSnapshot): AiCoachContextReadinessStatus {
  if (!snapshot.tenantPresent) return 'blocked'
  if (!snapshot.setupQueryOk) return 'partial'
  if (
    (snapshot.setupReadinessPct ?? 0) >= 50 &&
    (snapshot.departmentCount ?? 0) >= 1 &&
    (snapshot.positionCount ?? 0) >= 1 &&
    (snapshot.employeeCount ?? 0) >= 1
  ) {
    return 'ready'
  }
  return 'partial'
}

function deriveConnectorRuntimeStatus(
  snapshot: AiCoachContextSnapshot,
): AiCoachContextReadinessStatus {
  if (!snapshot.tenantPresent) return 'blocked'
  if (snapshot.connectorConnectionCount === null || snapshot.connectorRuntimeJobCount === null) {
    return 'partial'
  }
  if (
    snapshot.connectorConnectionCount >= 1 &&
    ((snapshot.connectorRuntimeJobCount ?? 0) >= 1 ||
      (snapshot.connectorJobEventCount ?? 0) >= 1 ||
      (snapshot.connectorSafeActivityCount ?? 0) >= 1)
  ) {
    return 'ready'
  }
  if (snapshot.connectorConnectionCount >= 1 || (snapshot.sourceNamespaceCount ?? 0) >= 1) {
    return 'partial'
  }
  return 'partial'
}

function deriveEmployeeQualityStatus(snapshot: AiCoachContextSnapshot): AiCoachContextReadinessStatus {
  if (!snapshot.tenantPresent) return 'blocked'
  if (snapshot.employeeCount === null || snapshot.reportingLineCount === null) return 'partial'
  if (snapshot.employeeCount >= 10 && snapshot.reportingLineCount >= 1) return 'ready'
  return 'partial'
}

function deriveLeaveStatus(snapshot: AiCoachContextSnapshot): AiCoachContextReadinessStatus {
  if (!snapshot.tenantPresent) return 'blocked'
  if (
    snapshot.leaveTypeCount === null ||
    snapshot.leaveBalanceCount === null ||
    snapshot.leaveRequestCount === null
  ) {
    return 'partial'
  }
  if (
    snapshot.leaveTypeCount >= 1 &&
    snapshot.leaveBalanceCount >= 1 &&
    snapshot.leaveRequestCount >= 1
  ) {
    return 'ready'
  }
  return 'partial'
}

function deriveExpenseStatus(snapshot: AiCoachContextSnapshot): AiCoachContextReadinessStatus {
  if (!snapshot.tenantPresent) return 'blocked'
  if (snapshot.expenseCategoryCount === null || snapshot.expenseClaimCount === null) {
    return 'partial'
  }
  if (snapshot.expenseCategoryCount >= 1 && snapshot.expenseClaimCount >= 1) return 'ready'
  return 'partial'
}

function derivePerformanceStatus(snapshot: AiCoachContextSnapshot): AiCoachContextReadinessStatus {
  if (!snapshot.tenantPresent) return 'blocked'
  if (
    snapshot.performanceCycleCount === null ||
    snapshot.competencyTemplateCount === null ||
    snapshot.performanceScoreCount === null ||
    snapshot.competencyEvaluationCount === null
  ) {
    return 'partial'
  }
  const perfRows = snapshot.performanceScoreCount + snapshot.competencyEvaluationCount
  if (
    snapshot.performanceCycleCount >= 1 &&
    snapshot.competencyTemplateCount >= 1 &&
    perfRows >= 1
  ) {
    return 'ready'
  }
  return 'partial'
}

function deriveContractsStatus(snapshot: AiCoachContextSnapshot): AiCoachContextReadinessStatus {
  if (!snapshot.tenantPresent) return 'blocked'
  if (snapshot.contractCount === null || !snapshot.contractsOverviewPresent) return 'partial'
  if (snapshot.contractCount >= 1) return 'ready'
  return 'partial'
}

function deriveDashboardStatus(snapshot: AiCoachContextSnapshot): AiCoachContextReadinessStatus {
  if (!snapshot.tenantPresent) return 'blocked'
  if (!snapshot.dashboardOverviewPresent) return 'partial'
  return 'ready'
}

function deriveProfileStatus(snapshot: AiCoachContextSnapshot): AiCoachContextReadinessStatus {
  if (!snapshot.tenantPresent) return 'blocked'
  if (!snapshot.employeeId) return 'partial'
  return 'ready'
}

const DOMAIN_META: Record<
  AiCoachContextDomainId,
  { titleKey: string; descriptionKey: string; guardrailKey: string; route: string }
> = {
  setup: {
    titleKey: 'aiCoachSetup.contextDomains.setup.title',
    descriptionKey: 'aiCoachSetup.contextDomains.setup.description',
    guardrailKey: 'aiCoachSetup.contextDomains.setup.guardrail',
    route: '/sirket-kurulum',
  },
  connector_runtime: {
    titleKey: 'aiCoachSetup.contextDomains.connector_runtime.title',
    descriptionKey: 'aiCoachSetup.contextDomains.connector_runtime.description',
    guardrailKey: 'aiCoachSetup.contextDomains.connector_runtime.guardrail',
    route: '/erp',
  },
  employee_quality: {
    titleKey: 'aiCoachSetup.contextDomains.employee_quality.title',
    descriptionKey: 'aiCoachSetup.contextDomains.employee_quality.description',
    guardrailKey: 'aiCoachSetup.contextDomains.employee_quality.guardrail',
    route: '/calisanlar',
  },
  leave: {
    titleKey: 'aiCoachSetup.contextDomains.leave.title',
    descriptionKey: 'aiCoachSetup.contextDomains.leave.description',
    guardrailKey: 'aiCoachSetup.contextDomains.leave.guardrail',
    route: '/izin',
  },
  expense: {
    titleKey: 'aiCoachSetup.contextDomains.expense.title',
    descriptionKey: 'aiCoachSetup.contextDomains.expense.description',
    guardrailKey: 'aiCoachSetup.contextDomains.expense.guardrail',
    route: '/masraf',
  },
  performance: {
    titleKey: 'aiCoachSetup.contextDomains.performance.title',
    descriptionKey: 'aiCoachSetup.contextDomains.performance.description',
    guardrailKey: 'aiCoachSetup.contextDomains.performance.guardrail',
    route: '/performans',
  },
  contracts: {
    titleKey: 'aiCoachSetup.contextDomains.contracts.title',
    descriptionKey: 'aiCoachSetup.contextDomains.contracts.description',
    guardrailKey: 'aiCoachSetup.contextDomains.contracts.guardrail',
    route: '/sozlesmeler',
  },
  dashboard: {
    titleKey: 'aiCoachSetup.contextDomains.dashboard.title',
    descriptionKey: 'aiCoachSetup.contextDomains.dashboard.description',
    guardrailKey: 'aiCoachSetup.contextDomains.dashboard.guardrail',
    route: '/dashboard',
  },
  profile: {
    titleKey: 'aiCoachSetup.contextDomains.profile.title',
    descriptionKey: 'aiCoachSetup.contextDomains.profile.description',
    guardrailKey: 'aiCoachSetup.contextDomains.profile.guardrail',
    route: '/profil',
  },
}

const STATUS_DERIVERS: Record<
  AiCoachContextDomainId,
  (snapshot: AiCoachContextSnapshot) => AiCoachContextReadinessStatus
> = {
  setup: deriveSetupStatus,
  connector_runtime: deriveConnectorRuntimeStatus,
  employee_quality: deriveEmployeeQualityStatus,
  leave: deriveLeaveStatus,
  expense: deriveExpenseStatus,
  performance: derivePerformanceStatus,
  contracts: deriveContractsStatus,
  dashboard: deriveDashboardStatus,
  profile: deriveProfileStatus,
}

function buildDomainEvidence(
  id: AiCoachContextDomainId,
  snapshot: AiCoachContextSnapshot,
): AiCoachContextDomain['evidence'] {
  switch (id) {
    case 'setup':
      return [
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.overallReadinessPct',
          snapshot.setupReadinessPct !== null ? Math.round(snapshot.setupReadinessPct) : null,
          snapshot.setupQueryOk,
        ),
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.departmentCount',
          snapshot.departmentCount,
          snapshot.departmentCount !== null,
        ),
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.positionCount',
          snapshot.positionCount,
          snapshot.positionCount !== null,
        ),
      ]
    case 'connector_runtime':
      return [
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.connectorConnectionCount',
          snapshot.connectorConnectionCount,
          snapshot.connectorConnectionCount !== null,
        ),
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.connectorRuntimeJobCount',
          snapshot.connectorRuntimeJobCount,
          snapshot.connectorRuntimeJobCount !== null,
        ),
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.connectorJobEventCount',
          snapshot.connectorJobEventCount,
          snapshot.connectorJobEventCount !== null,
        ),
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.connectorCredentialVerifiedCount',
          snapshot.connectorCredentialVerifiedCount,
          snapshot.connectorCredentialVerifiedCount !== null,
        ),
      ]
    case 'employee_quality':
      return [
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.employeeCount',
          snapshot.employeeCount,
          snapshot.employeeCount !== null,
        ),
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.reportingLineCount',
          snapshot.reportingLineCount,
          snapshot.reportingLineCount !== null,
        ),
      ]
    case 'leave':
      return [
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.leaveTypeCount',
          snapshot.leaveTypeCount,
          snapshot.leaveTypeCount !== null,
        ),
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.leaveRequestCount',
          snapshot.leaveRequestCount,
          snapshot.leaveRequestCount !== null,
        ),
      ]
    case 'expense':
      return [
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.expenseCategoryCount',
          snapshot.expenseCategoryCount,
          snapshot.expenseCategoryCount !== null,
        ),
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.expenseClaimCount',
          snapshot.expenseClaimCount,
          snapshot.expenseClaimCount !== null,
        ),
      ]
    case 'performance':
      return [
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.performanceCycleCount',
          snapshot.performanceCycleCount,
          snapshot.performanceCycleCount !== null,
        ),
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.competencyTemplateCount',
          snapshot.competencyTemplateCount,
          snapshot.competencyTemplateCount !== null,
        ),
      ]
    case 'contracts':
      return [
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.contractCount',
          snapshot.contractCount,
          snapshot.contractCount !== null,
        ),
        {
          labelKey: 'aiCoachSetup.contextDomains.evidence.contractsOverview',
          value: snapshot.contractsOverviewPresent,
        },
      ]
    case 'dashboard':
      return [
        {
          labelKey: 'aiCoachSetup.contextDomains.evidence.dashboardOverview',
          value: snapshot.dashboardOverviewPresent,
        },
        countEvidence(
          'aiCoachSetup.contextDomains.evidence.pendingLeaveCount',
          snapshot.leaveRequestCount,
          snapshot.leaveRequestCount !== null,
        ),
      ]
    case 'profile':
      return [
        {
          labelKey: 'aiCoachSetup.contextDomains.evidence.employeeLinked',
          value: Boolean(snapshot.employeeId),
        },
        {
          labelKey: 'aiCoachSetup.contextDomains.evidence.employeeName',
          value: snapshot.employeeName ?? '—',
        },
      ]
    default:
      return []
  }
}

export function buildAiCoachContextDomains(
  snapshot: AiCoachContextSnapshot,
  sourcePosture: 'real' | 'demo' | 'not_applicable' = 'real',
): AiCoachContextDomain[] {
  const domainIds = Object.keys(DOMAIN_META) as AiCoachContextDomainId[]

  return domainIds.map((id) => {
    const meta = DOMAIN_META[id]
    return {
      id,
      titleKey: meta.titleKey,
      descriptionKey: meta.descriptionKey,
      status: STATUS_DERIVERS[id](snapshot),
      sourcePosture,
      evidence: buildDomainEvidence(id, snapshot),
      guardrailKey: meta.guardrailKey,
      route: meta.route,
    }
  })
}

const ALLOWED_RUNTIME_EVIDENCE_ACTIONS: AiCoachRuntimeEvidenceActionId[] = [
  'explain',
  'summarize',
  'detect_gap',
  'recommend_next_step',
  'prepare_review',
  'source_disclosure',
]

const FORBIDDEN_RUNTIME_EVIDENCE_ACTIONS: AiCoachRuntimeEvidenceForbiddenActionId[] = [
  'start_connector_job',
  'read_credential',
  'apply_import',
  'write_to_source',
  'mutate_workflow',
]

function buildRuntimeSignal(
  id: string,
  labelKey: string,
  value: number | string | boolean | null,
  sourceKey: string,
  disclosureKey: string,
): AiCoachRuntimeEvidenceSignal {
  return {
    id,
    labelKey,
    value: value ?? QUERY_UNAVAILABLE,
    sourceKey,
    disclosureKey,
    status: value === null ? 'partial' : 'ready',
  }
}

export function buildRuntimeEvidenceContract(
  snapshot: AiCoachContextSnapshot,
): AiCoachRuntimeEvidenceContract {
  const runtimeBlockers =
    (snapshot.connectorRuntimeFailedJobCount ?? 0) +
    (snapshot.connectorRuntimeDeadLetterJobCount ?? 0) +
    (snapshot.connectorCredentialMissingCount ?? 0)

  return {
    sourceDisclosureRequired: true,
    signals: [
      buildRuntimeSignal(
        'connector_jobs',
        'aiCoachSetup.runtimeEvidence.signals.connectorJobs.label',
        snapshot.connectorRuntimeJobCount,
        'aiCoachSetup.runtimeEvidence.sources.connectorJobs',
        'aiCoachSetup.runtimeEvidence.disclosures.connectorJobs',
      ),
      buildRuntimeSignal(
        'connector_job_events',
        'aiCoachSetup.runtimeEvidence.signals.connectorJobEvents.label',
        snapshot.connectorJobEventCount,
        'aiCoachSetup.runtimeEvidence.sources.connectorJobEvents',
        'aiCoachSetup.runtimeEvidence.disclosures.connectorJobEvents',
      ),
      buildRuntimeSignal(
        'credential_state',
        'aiCoachSetup.runtimeEvidence.signals.credentialState.label',
        snapshot.connectorCredentialVerifiedCount,
        'aiCoachSetup.runtimeEvidence.sources.credentialState',
        'aiCoachSetup.runtimeEvidence.disclosures.credentialState',
      ),
      buildRuntimeSignal(
        'import_preview',
        'aiCoachSetup.runtimeEvidence.signals.importPreview.label',
        snapshot.connectorImportPreviewBatchCount,
        'aiCoachSetup.runtimeEvidence.sources.importPreview',
        'aiCoachSetup.runtimeEvidence.disclosures.importPreview',
      ),
      buildRuntimeSignal(
        'runtime_blockers',
        'aiCoachSetup.runtimeEvidence.signals.runtimeBlockers.label',
        runtimeBlockers,
        'aiCoachSetup.runtimeEvidence.sources.runtimeBlockers',
        'aiCoachSetup.runtimeEvidence.disclosures.runtimeBlockers',
      ),
    ],
    allowedSuggestionActions: ALLOWED_RUNTIME_EVIDENCE_ACTIONS,
    forbiddenActions: FORBIDDEN_RUNTIME_EVIDENCE_ACTIONS,
  }
}

export function buildLegacyReadiness(snapshot: AiCoachContextSnapshot): AiCoachReadinessItem[] {
  const erpReady =
    (snapshot.sourceNamespaceCount ?? 0) >= 1 || snapshot.inactiveErpConnectionPresent

  return [
    { id: 'r1', labelKey: 'aiCoachSetup.readiness.vaultSchema', status: 'done' },
    { id: 'r2', labelKey: 'aiCoachSetup.readiness.toolCallLayer', status: 'pending' },
    {
      id: 'r3',
      labelKey: 'aiCoachSetup.readiness.erpContext',
      status: erpReady ? 'done' : 'pending',
    },
  ]
}

export function deriveAiCoachProductPosture(
  domains: AiCoachContextDomain[],
): AiCoachProductPosture {
  if (domains.length === 0) return 'teaser_context_partial'

  const readyCount = domains.filter((domain) => domain.status === 'ready').length
  const blockedCount = domains.filter((domain) => domain.status === 'blocked').length

  if (blockedCount === domains.length) return 'teaser_context_partial'
  if (readyCount >= 6) return 'teaser_context_ready'
  return 'teaser_context_partial'
}

export function buildBlockedContextSnapshot(): AiCoachContextSnapshot {
  return {
    tenantPresent: false,
    employeeId: null,
    employeeName: null,
    setupReadinessPct: null,
    setupQueryOk: false,
    departmentCount: null,
    positionCount: null,
    employeeCount: null,
    reportingLineCount: null,
    leaveTypeCount: null,
    leaveBalanceCount: null,
    leaveRequestCount: null,
    expenseCategoryCount: null,
    expenseClaimCount: null,
    performanceCycleCount: null,
    competencyTemplateCount: null,
    performanceScoreCount: null,
    competencyEvaluationCount: null,
    contractCount: null,
    contractsOverviewPresent: false,
    dashboardOverviewPresent: false,
    sourceNamespaceCount: null,
    inactiveErpConnectionPresent: false,
    connectorConnectionCount: null,
    connectorRuntimeJobCount: null,
    connectorRuntimeFailedJobCount: null,
    connectorRuntimeDeadLetterJobCount: null,
    connectorJobEventCount: null,
    connectorCredentialVerifiedCount: null,
    connectorCredentialMissingCount: null,
    connectorImportPreviewBatchCount: null,
    connectorSafeActivityCount: null,
    leaveOverviewPresent: false,
    expenseOverviewPresent: false,
    performanceOverviewPresent: false,
  }
}

export function buildAiCoachOverviewFromSnapshot(
  snapshot: AiCoachContextSnapshot,
  sourcePosture: 'real' | 'demo' | 'not_applicable' = 'real',
): AiCoachOverview {
  const contextDomains = buildAiCoachContextDomains(snapshot, sourcePosture)

  return {
    capabilities: DEFAULT_CAPABILITIES,
    readiness: buildLegacyReadiness(snapshot),
    contextDomains,
    guardrails: buildDefaultGuardrails(),
    runtimeEvidence: buildRuntimeEvidenceContract(snapshot),
    productPosture: deriveAiCoachProductPosture(contextDomains),
  }
}

export function buildBlockedAiCoachOverview(): AiCoachOverview {
  return buildAiCoachOverviewFromSnapshot(buildBlockedContextSnapshot(), 'not_applicable')
}

function buildDemoContextDomains(): AiCoachContextDomain[] {
  const snapshot: AiCoachContextSnapshot = {
    tenantPresent: true,
    employeeId: 'demo-employee',
    employeeName: 'Demo Employee',
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
    connectorConnectionCount: 1,
    connectorRuntimeJobCount: 4,
    connectorRuntimeFailedJobCount: 1,
    connectorRuntimeDeadLetterJobCount: 0,
    connectorJobEventCount: 6,
    connectorCredentialVerifiedCount: 0,
    connectorCredentialMissingCount: 1,
    connectorImportPreviewBatchCount: 1,
    connectorSafeActivityCount: 3,
    leaveOverviewPresent: true,
    expenseOverviewPresent: true,
    performanceOverviewPresent: true,
  }

  return buildAiCoachContextDomains(snapshot, 'demo')
}

export async function buildDemoAiCoachOverview(): Promise<AiCoachOverview> {
  const legacy = await fetchDemoAiCoachOverview()

  return {
    capabilities: legacy.capabilities.map((capability) => ({
      id: capability.id,
      titleKey: capability.titleKey,
      descKey: capability.descKey,
    })),
    readiness: legacy.readiness.map((item) => ({
      id: item.id,
      labelKey: item.labelKey,
      status: item.status,
    })),
    contextDomains: buildDemoContextDomains(),
    guardrails: buildDefaultGuardrails(),
    runtimeEvidence: buildRuntimeEvidenceContract({
      tenantPresent: true,
      employeeId: 'demo-employee',
      employeeName: 'Demo Employee',
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
      connectorConnectionCount: 1,
      connectorRuntimeJobCount: 4,
      connectorRuntimeFailedJobCount: 1,
      connectorRuntimeDeadLetterJobCount: 0,
      connectorJobEventCount: 6,
      connectorCredentialVerifiedCount: 0,
      connectorCredentialMissingCount: 1,
      connectorImportPreviewBatchCount: 1,
      connectorSafeActivityCount: 3,
      leaveOverviewPresent: true,
      expenseOverviewPresent: true,
      performanceOverviewPresent: true,
    }),
    productPosture: 'teaser_context_partial',
  }
}

export function isAiCoachOverviewEmpty(data: AiCoachOverview): boolean {
  return (
    data.productPosture === 'teaser_context_partial' &&
    data.contextDomains.every((domain) => domain.status === 'blocked')
  )
}

export function productPostureLabelKey(
  posture: AiCoachProductPosture,
): 'aiCoachSetup.productPosture.ready' | 'aiCoachSetup.productPosture.partial' {
  return posture === 'teaser_context_ready'
    ? 'aiCoachSetup.productPosture.ready'
    : 'aiCoachSetup.productPosture.partial'
}
