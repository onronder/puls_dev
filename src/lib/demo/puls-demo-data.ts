export type LeaveStatus = 'pending' | 'approved' | 'rejected' | 'cancelled'

export type DemoLeaveBalance = {
  typeCode: 'annual' | 'excuse' | 'sick'
  labelKey: string
  totalDays: number
  usedDays: number
  remainingDays: number
}

export type DemoLeaveRequest = {
  id: string
  typeLabel: string
  startDate: string
  endDate: string
  businessDays: number
  delegateName?: string
  status: LeaveStatus
  approverName?: string
}

export type DemoExpenseClaim = {
  id: string
  title: string
  category: string
  amount: number
  currency: string
  expenseDate: string
  status: 'draft' | 'pending' | 'approved' | 'rejected' | 'paid'
}

export type DemoLeaveOverview = {
  heroRemainingAnnual: number
  heroUsedAnnual: number
  heroTotalAnnual: number
  balances: DemoLeaveBalance[]
  pendingCount: number
  requests: DemoLeaveRequest[]
  leaveTypes: { id: string; label: string }[]
  delegates: { id: string; name: string }[]
}

export type DemoExpenseOverview = {
  approvedThisMonth: number
  monthlyLimit: number
  pendingAmount: number
  pendingCount: number
  yearTotal: number
  topCategoryShare: string
  monthlyAverage: number
  claims: DemoExpenseClaim[]
  categories: { id: string; label: string }[]
}

const demoLeaveOverview: DemoLeaveOverview = {
  heroRemainingAnnual: 14,
  heroUsedAnnual: 6,
  heroTotalAnnual: 20,
  pendingCount: 2,
  balances: [
    {
      typeCode: 'annual',
      labelKey: 'leave.types.annual',
      totalDays: 20,
      usedDays: 6,
      remainingDays: 14,
    },
    {
      typeCode: 'excuse',
      labelKey: 'leave.types.excuse',
      totalDays: 10,
      usedDays: 3,
      remainingDays: 7,
    },
    {
      typeCode: 'sick',
      labelKey: 'leave.types.sick',
      totalDays: 10,
      usedDays: 0,
      remainingDays: 10,
    },
  ],
  requests: [
    {
      id: 'lr-1',
      typeLabel: 'Yıllık İzin',
      startDate: '2026-07-14',
      endDate: '2026-07-18',
      businessDays: 5,
      delegateName: 'Özge Büyüksahin',
      status: 'pending',
    },
    {
      id: 'lr-2',
      typeLabel: 'Mazeret İzni',
      startDate: '2026-05-02',
      endDate: '2026-05-02',
      businessDays: 1,
      status: 'approved',
      approverName: 'Mehmet Kaya',
    },
    {
      id: 'lr-3',
      typeLabel: 'Yıllık İzin',
      startDate: '2026-03-10',
      endDate: '2026-03-14',
      businessDays: 5,
      status: 'approved',
      approverName: 'Demo İK Yöneticisi',
    },
    {
      id: 'lr-4',
      typeLabel: 'Mazeret İzni',
      startDate: '2026-06-20',
      endDate: '2026-06-21',
      businessDays: 2,
      status: 'pending',
    },
  ],
  leaveTypes: [
    { id: 'annual', label: 'Yıllık İzin' },
    { id: 'excuse', label: 'Mazeret İzni' },
    { id: 'sick', label: 'Hastalık İzni' },
    { id: 'birth', label: 'Doğum İzni' },
    { id: 'marriage', label: 'Evlilik İzni' },
    { id: 'bereavement', label: 'Ölüm İzni' },
    { id: 'unpaid', label: 'Ücretsiz İzin' },
    { id: 'comp', label: 'Telafi İzni' },
  ],
  delegates: [
    { id: 'ozge', name: 'Özge Büyüksahin' },
    { id: 'ayse', name: 'Ayşe Demir' },
    { id: 'mehmet', name: 'Mehmet Kaya' },
  ],
}

const demoExpenseOverview: DemoExpenseOverview = {
  approvedThisMonth: 8640,
  monthlyLimit: 15000,
  pendingAmount: 2340,
  pendingCount: 2,
  yearTotal: 34200,
  topCategoryShare: 'Seyahat %41',
  monthlyAverage: 4900,
  claims: [
    {
      id: 'ex-1',
      title: 'İstanbul–Ankara uçak',
      category: 'Seyahat',
      amount: 1890,
      currency: 'TRY',
      expenseDate: '2026-05-10',
      status: 'pending',
    },
    {
      id: 'ex-2',
      title: 'İş yemeği',
      category: 'Yemek',
      amount: 450,
      currency: 'TRY',
      expenseDate: '2026-05-08',
      status: 'pending',
    },
    {
      id: 'ex-3',
      title: 'Konaklama',
      category: 'Konaklama',
      amount: 3200,
      currency: 'TRY',
      expenseDate: '2026-04-22',
      status: 'approved',
    },
    {
      id: 'ex-4',
      title: 'Taksi',
      category: 'Ulaşım',
      amount: 280,
      currency: 'TRY',
      expenseDate: '2026-04-18',
      status: 'approved',
    },
    {
      id: 'ex-5',
      title: 'Eğitim materyali',
      category: 'Eğitim',
      amount: 890,
      currency: 'TRY',
      expenseDate: '2026-03-05',
      status: 'approved',
    },
    {
      id: 'ex-6',
      title: 'Temsil gideri',
      category: 'Temsil',
      amount: 1200,
      currency: 'TRY',
      expenseDate: '2026-02-14',
      status: 'rejected',
    },
  ],
  categories: [
    { id: 'travel', label: 'Seyahat' },
    { id: 'lodging', label: 'Konaklama' },
    { id: 'food', label: 'Yemek' },
    { id: 'entertainment', label: 'Temsil' },
    { id: 'training', label: 'Eğitim' },
    { id: 'office', label: 'Ofis' },
    { id: 'transport', label: 'Ulaşım' },
  ],
}

export async function fetchDemoLeaveOverview(): Promise<DemoLeaveOverview> {
  return demoLeaveOverview
}

export async function fetchDemoExpenseOverview(): Promise<DemoExpenseOverview> {
  return demoExpenseOverview
}

export function formatTry(amount: number, locale = 'tr-TR'): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency: 'TRY',
    maximumFractionDigits: 0,
  }).format(amount)
}

export function formatPercent(value: number): string {
  return `${Math.round(value)}%`
}

export type DemoErpMappingStatus = 'mapped' | 'pending'
export type DemoErpSyncLevel = 'success' | 'warning' | 'info'

export type DemoErpOverview = {
  status: {
    system: 'Canias'
    status: 'beklemede'
    statusLabel: string
    mappedFields: number
    totalFields: number
    lastAttempt: string
    readiness: number
  }
  mappings: Array<{
    puls: string
    erp: string
    status: DemoErpMappingStatus
  }>
  syncLogs: Array<{
    id: string
    at: string
    level: DemoErpSyncLevel
    message: string
  }>
}

const demoErpOverview: DemoErpOverview = {
  status: {
    system: 'Canias',
    status: 'beklemede',
    statusLabel: 'API erişimi bekleniyor',
    mappedFields: 6,
    totalFields: 11,
    lastAttempt: 'Dün, 18:42',
    readiness: 72,
  },
  mappings: [
    { puls: 'Sicil no', erp: 'PERS_NO', status: 'mapped' },
    { puls: 'Ad soyad', erp: 'AD_SOYAD', status: 'mapped' },
    { puls: 'Departman', erp: 'DEPT_KOD', status: 'mapped' },
    { puls: 'Pozisyon', erp: 'POZ_KOD', status: 'mapped' },
    { puls: 'Yönetici', erp: 'YON_PERS_NO', status: 'mapped' },
    { puls: 'İşe giriş tarihi', erp: 'ISE_GIRIS', status: 'mapped' },
    { puls: 'E-posta', erp: '—', status: 'pending' },
    { puls: 'Durum', erp: '—', status: 'pending' },
    { puls: 'Telefon', erp: '—', status: 'pending' },
    { puls: 'Lokasyon', erp: '—', status: 'pending' },
    { puls: 'Vardiya', erp: '—', status: 'pending' },
  ],
  syncLogs: [
    {
      id: 's1',
      at: 'Dün 18:42',
      level: 'info',
      message: 'Bağlantı denendi · zaman aşımı',
    },
    {
      id: 's2',
      at: 'Dün 18:40',
      level: 'warning',
      message: 'Kimlik doğrulama bekleniyor (müşteri tarafı)',
    },
    {
      id: 's3',
      at: 'Dün 14:10',
      level: 'success',
      message: 'Alan şeması hazırlandı · 11 alan',
    },
    {
      id: 's4',
      at: '16 May 09:22',
      level: 'info',
      message: 'Mapping taslağı oluşturuldu',
    },
  ],
}

export async function fetchDemoErpOverview(): Promise<DemoErpOverview> {
  return demoErpOverview
}

export type DemoCompanySetupChecklistStatus = 'done' | 'pending'

export type DemoCompanySetup = {
  name: string
  vkn: string
  sector: string
  band: string
  language: string
  timezone: string
  package: string
  completion: number
  missing: number
  erpReadiness: string
  checklist: Array<{
    id: string
    labelKey: string
    status: DemoCompanySetupChecklistStatus
  }>
}

const demoCompanySetup: DemoCompanySetup = {
  name: 'Mert Teknik A.Ş.',
  vkn: '—',
  sector: 'Üretim / Teknik servis',
  band: '1-50 çalışan',
  language: 'tr-TR',
  timezone: 'Europe/Istanbul',
  package: 'Pilot',
  completion: 72,
  missing: 3,
  erpReadiness: '6 / 12',
  checklist: [
    { id: 'ck1', labelKey: 'companySetup.checklist.tenant', status: 'done' },
    { id: 'ck2', labelKey: 'companySetup.checklist.employees', status: 'done' },
    { id: 'ck3', labelKey: 'companySetup.checklist.erpMapping', status: 'pending' },
    { id: 'ck4', labelKey: 'companySetup.checklist.performanceCycle', status: 'pending' },
  ],
}

export async function fetchDemoCompanySetup(): Promise<DemoCompanySetup> {
  return demoCompanySetup
}

export type DemoDepartmentStatus = 'active'

export type DemoDepartment = {
  id: string
  name: string
  manager: string
  count: number
  status: DemoDepartmentStatus
}

export type DemoDepartmentsOverview = {
  departmentCount: number
  activeEmployees: number
  assignedManagers: number
  emptyManagers: number
  departments: DemoDepartment[]
}

const demoDepartmentsOverview: DemoDepartmentsOverview = {
  departmentCount: 3,
  activeEmployees: 4,
  assignedManagers: 3,
  emptyManagers: 0,
  departments: [
    { id: 'd1', name: 'Mühendislik', manager: 'Murat Tan', count: 2, status: 'active' },
    { id: 'd2', name: 'Operasyon', manager: 'Elif Demir', count: 1, status: 'active' },
    { id: 'd3', name: 'İK & Finans', manager: 'Demo İK Yöneticisi', count: 1, status: 'active' },
  ],
}

export async function fetchDemoDepartmentsOverview(): Promise<DemoDepartmentsOverview> {
  return demoDepartmentsOverview
}

export type DemoPosition = {
  id: string
  name: string
  department: string
  template: string
  evaluation: number
  open: number
}

export type DemoPositionsOverview = {
  positionCount: number
  openPositions: number
  templateLinked: number
  evaluationComplete: number
  positions: DemoPosition[]
}

const demoPositionsOverview: DemoPositionsOverview = {
  positionCount: 3,
  openPositions: 0,
  templateLinked: 3,
  evaluationComplete: 3,
  positions: [
    {
      id: 'p1',
      name: 'İK Yöneticisi',
      department: 'İK & Finans',
      template: 'Yönetici',
      evaluation: 855,
      open: 0,
    },
    {
      id: 'p2',
      name: 'Saha Mühendisi',
      department: 'Mühendislik',
      template: 'Saha Mühendisi',
      evaluation: 720,
      open: 0,
    },
    {
      id: 'p3',
      name: 'Operasyon Uzmanı',
      department: 'Operasyon',
      template: 'Ofis & Operasyon',
      evaluation: 645,
      open: 0,
    },
  ],
}

export async function fetchDemoPositionsOverview(): Promise<DemoPositionsOverview> {
  return demoPositionsOverview
}

export type DemoLeaveTypeRule = {
  id: string
  labelKey: string
  days: number
  paid: boolean
  doc: boolean
  carryOver: boolean
}

export type DemoLeaveTypesOverview = {
  typeCount: number
  paidCount: number
  docRequiredCount: number
  leaveTypes: DemoLeaveTypeRule[]
}

const demoLeaveTypesOverview: DemoLeaveTypesOverview = {
  typeCount: 8,
  paidCount: 6,
  docRequiredCount: 2,
  leaveTypes: [
    {
      id: 'yillik',
      labelKey: 'leaveTypeSetup.types.annual',
      days: 20,
      paid: true,
      doc: false,
      carryOver: true,
    },
    {
      id: 'mazeret',
      labelKey: 'leaveTypeSetup.types.excuse',
      days: 10,
      paid: true,
      doc: false,
      carryOver: false,
    },
    {
      id: 'hastalik',
      labelKey: 'leaveTypeSetup.types.sick',
      days: 10,
      paid: true,
      doc: true,
      carryOver: false,
    },
    {
      id: 'ucretsiz',
      labelKey: 'leaveTypeSetup.types.unpaid',
      days: 30,
      paid: false,
      doc: false,
      carryOver: false,
    },
    {
      id: 'idari',
      labelKey: 'leaveTypeSetup.types.administrative',
      days: 5,
      paid: true,
      doc: false,
      carryOver: false,
    },
    {
      id: 'evlilik',
      labelKey: 'leaveTypeSetup.types.marriage',
      days: 3,
      paid: true,
      doc: true,
      carryOver: false,
    },
    {
      id: 'dogum',
      labelKey: 'leaveTypeSetup.types.parental',
      days: 16,
      paid: true,
      doc: false,
      carryOver: false,
    },
    {
      id: 'olum',
      labelKey: 'leaveTypeSetup.types.bereavement',
      days: 3,
      paid: true,
      doc: false,
      carryOver: false,
    },
  ],
}

export async function fetchDemoLeaveTypesOverview(): Promise<DemoLeaveTypesOverview> {
  return demoLeaveTypesOverview
}

export type DemoExpenseCategoryRule = {
  id: string
  nameKey: string
  monthly: number
  docThreshold: number
  code: string
}

export type DemoExpenseCategoriesOverview = {
  categoryCount: number
  totalMonthlyLimit: number
  docThresholdMetric: number
  approvalLevels: number
  categories: DemoExpenseCategoryRule[]
}

const demoExpenseCategoriesOverview: DemoExpenseCategoriesOverview = {
  categoryCount: 6,
  totalMonthlyLimit: 55000,
  docThresholdMetric: 2000,
  approvalLevels: 2,
  categories: [
    {
      id: 'ec1',
      nameKey: 'expenseCategorySetup.categories.travel',
      monthly: 15000,
      docThreshold: 2000,
      code: '770.01',
    },
    {
      id: 'ec2',
      nameKey: 'expenseCategorySetup.categories.meals',
      monthly: 5000,
      docThreshold: 500,
      code: '770.02',
    },
    {
      id: 'ec3',
      nameKey: 'expenseCategorySetup.categories.lodging',
      monthly: 20000,
      docThreshold: 2000,
      code: '770.03',
    },
    {
      id: 'ec4',
      nameKey: 'expenseCategorySetup.categories.software',
      monthly: 10000,
      docThreshold: 1000,
      code: '770.04',
    },
    {
      id: 'ec5',
      nameKey: 'expenseCategorySetup.categories.transport',
      monthly: 3000,
      docThreshold: 500,
      code: '770.05',
    },
    {
      id: 'ec6',
      nameKey: 'expenseCategorySetup.categories.other',
      monthly: 2000,
      docThreshold: 500,
      code: '770.99',
    },
  ],
}

export async function fetchDemoExpenseCategoriesOverview(): Promise<DemoExpenseCategoriesOverview> {
  return demoExpenseCategoriesOverview
}

export type DemoPerformanceScoreBandTone = 'success' | 'info' | 'neutral' | 'warning' | 'danger'

export type DemoPerformanceCompetencyTemplate = {
  id: string
  nameKey: string
  areas: number
  updatedAt: string
}

export type DemoPerformanceKpiCategory = {
  id: string
  nameKey: string
  weight: number
}

export type DemoPerformanceScoreBand = {
  id: string
  labelKey: string
  min: number
  max: number
  tone: DemoPerformanceScoreBandTone
}

export type DemoPerformanceParametersOverview = {
  competencyTemplateCount: number
  kpiCategoryCount: number
  scoreBandCount: number
  hasActiveCycle: boolean
  competencyTemplates: DemoPerformanceCompetencyTemplate[]
  kpiCategories: DemoPerformanceKpiCategory[]
  scoreBands: DemoPerformanceScoreBand[]
}

const demoPerformanceParametersOverview: DemoPerformanceParametersOverview = {
  competencyTemplateCount: 3,
  kpiCategoryCount: 4,
  scoreBandCount: 5,
  hasActiveCycle: false,
  competencyTemplates: [
    {
      id: 't1',
      nameKey: 'performanceParamsSetup.templates.fieldEngineer',
      areas: 6,
      updatedAt: '2026-04-12',
    },
    {
      id: 't2',
      nameKey: 'performanceParamsSetup.templates.officeOperations',
      areas: 5,
      updatedAt: '2026-04-08',
    },
    {
      id: 't3',
      nameKey: 'performanceParamsSetup.templates.manager',
      areas: 7,
      updatedAt: '2026-03-01',
    },
  ],
  kpiCategories: [
    { id: 'k1', nameKey: 'performanceParamsSetup.kpi.operational', weight: 35 },
    { id: 'k2', nameKey: 'performanceParamsSetup.kpi.customer', weight: 25 },
    { id: 'k3', nameKey: 'performanceParamsSetup.kpi.financial', weight: 20 },
    { id: 'k4', nameKey: 'performanceParamsSetup.kpi.development', weight: 20 },
  ],
  scoreBands: [
    {
      id: 'sb1',
      labelKey: 'performanceParamsSetup.scoreBands.excellent',
      min: 90,
      max: 100,
      tone: 'success',
    },
    {
      id: 'sb2',
      labelKey: 'performanceParamsSetup.scoreBands.good',
      min: 75,
      max: 89,
      tone: 'info',
    },
    {
      id: 'sb3',
      labelKey: 'performanceParamsSetup.scoreBands.expected',
      min: 60,
      max: 74,
      tone: 'neutral',
    },
    {
      id: 'sb4',
      labelKey: 'performanceParamsSetup.scoreBands.development',
      min: 45,
      max: 59,
      tone: 'warning',
    },
    {
      id: 'sb5',
      labelKey: 'performanceParamsSetup.scoreBands.risk',
      min: 0,
      max: 44,
      tone: 'danger',
    },
  ],
}

export async function fetchDemoPerformanceParametersOverview(): Promise<DemoPerformanceParametersOverview> {
  return demoPerformanceParametersOverview
}

export type DemoCareerLadderStep = {
  level: number
  titleKey: string
  current: boolean
  achieved: boolean
  target?: boolean
}

export type DemoCareerGap = {
  id: string
  nameKey: string
  current: number
  target: number
}

export type DemoDevelopmentPlanHorizon = 'd30' | 'd90' | 'd180'

export type DemoDevelopmentPlanItem = {
  id: string
  labelKey: string
}

export type DemoCareerOverview = {
  employee: {
    name: string
    initials: string
    positionKey: string
    departmentKey: string
  }
  readinessPercent: number
  targetRoleKey: string
  missingCompetencyCount: number
  recommendedTrainingCount: number
  ladderSubtitleKey: string
  careerLadder: DemoCareerLadderStep[]
  careerGaps: DemoCareerGap[]
  developmentPlan: Record<DemoDevelopmentPlanHorizon, DemoDevelopmentPlanItem[]>
}

const demoCareerOverview: DemoCareerOverview = {
  employee: {
    name: 'Ayşe Kaya',
    initials: 'AK',
    positionKey: 'careerSetup.employee.position',
    departmentKey: 'careerSetup.employee.department',
  },
  readinessPercent: 87,
  targetRoleKey: 'careerSetup.roles.teamLead',
  missingCompetencyCount: 3,
  recommendedTrainingCount: 2,
  ladderSubtitleKey: 'careerSetup.ladder.subtitle',
  careerLadder: [
    {
      level: 1,
      titleKey: 'careerSetup.ladder.fieldEngineer',
      current: false,
      achieved: true,
    },
    {
      level: 2,
      titleKey: 'careerSetup.ladder.seniorFieldEngineer',
      current: true,
      achieved: false,
    },
    {
      level: 3,
      titleKey: 'careerSetup.ladder.teamLead',
      current: false,
      achieved: false,
      target: true,
    },
    {
      level: 4,
      titleKey: 'careerSetup.ladder.operationsManager',
      current: false,
      achieved: false,
    },
  ],
  careerGaps: [
    { id: 'g1', nameKey: 'careerSetup.gaps.leadership', current: 2, target: 4 },
    { id: 'g2', nameKey: 'careerSetup.gaps.reporting', current: 3, target: 4 },
    { id: 'g3', nameKey: 'careerSetup.gaps.teamCoordination', current: 2, target: 4 },
  ],
  developmentPlan: {
    d30: [
      { id: 'd30-1', labelKey: 'careerSetup.plan.d30.item1' },
      { id: 'd30-2', labelKey: 'careerSetup.plan.d30.item2' },
    ],
    d90: [
      { id: 'd90-1', labelKey: 'careerSetup.plan.d90.item1' },
      { id: 'd90-2', labelKey: 'careerSetup.plan.d90.item2' },
    ],
    d180: [
      { id: 'd180-1', labelKey: 'careerSetup.plan.d180.item1' },
      { id: 'd180-2', labelKey: 'careerSetup.plan.d180.item2' },
    ],
  },
}

export async function fetchDemoCareerOverview(): Promise<DemoCareerOverview> {
  return demoCareerOverview
}

export type DemoTrainingStatus = 'suggested' | 'planned' | 'completed'

export type DemoTrainingItem = {
  id: string
  titleKey: string
  employeeName: string
  competencyKey: string
  hours: number
  status: DemoTrainingStatus
}

export type DemoTrainingOverview = {
  openNeedCount: number
  completedCount: number
  suggestedCount: number
  averageCompletionPercent: number
  trainings: DemoTrainingItem[]
}

const demoTrainingOverview: DemoTrainingOverview = {
  openNeedCount: 5,
  completedCount: 8,
  suggestedCount: 4,
  averageCompletionPercent: 76,
  trainings: [
    {
      id: 'tr1',
      titleKey: 'trainingSetup.trainings.leadership101',
      employeeName: 'Ayşe Kaya',
      competencyKey: 'trainingSetup.competencies.leadership',
      status: 'suggested',
      hours: 6,
    },
    {
      id: 'tr2',
      titleKey: 'trainingSetup.trainings.reportingKpi',
      employeeName: 'Ayşe Kaya',
      competencyKey: 'trainingSetup.competencies.reporting',
      status: 'planned',
      hours: 4,
    },
    {
      id: 'tr3',
      titleKey: 'trainingSetup.trainings.ohsRenewal',
      employeeName: 'Murat Tan',
      competencyKey: 'trainingSetup.competencies.ohs',
      status: 'completed',
      hours: 8,
    },
    {
      id: 'tr4',
      titleKey: 'trainingSetup.trainings.excelAdvanced',
      employeeName: 'Elif Demir',
      competencyKey: 'trainingSetup.competencies.analysis',
      status: 'completed',
      hours: 10,
    },
    {
      id: 'tr5',
      titleKey: 'trainingSetup.trainings.communication',
      employeeName: 'Murat Tan',
      competencyKey: 'trainingSetup.competencies.communication',
      status: 'suggested',
      hours: 4,
    },
  ],
}

export async function fetchDemoTrainingOverview(): Promise<DemoTrainingOverview> {
  return demoTrainingOverview
}

export type DemoJobEvaluationFactorKey = 'knowledge' | 'problem' | 'responsibility' | 'impact'

export type DemoJobEvaluationFactor = {
  key: DemoJobEvaluationFactorKey
  labelKey: string
  maxScore: number
}

export type DemoJobEvaluationPosition = {
  id: string
  positionKey: string
  bandKey: string
  total: number
  factors: Record<DemoJobEvaluationFactorKey, number>
}

export type DemoJobEvaluationLevelBand = {
  id: string
  levelKey: string
  rangeKey: string
  noteKey: string
  tone: 'success' | 'info' | 'neutral'
}

export type DemoJobEvaluationOverview = {
  evaluatedPositionCount: number
  averageScore: number
  highLevelCount: number
  missingEvaluationCount: number
  maxTotalScore: number
  evaluationFactors: DemoJobEvaluationFactor[]
  positions: DemoJobEvaluationPosition[]
  levelBands: DemoJobEvaluationLevelBand[]
}

const demoJobEvaluationOverview: DemoJobEvaluationOverview = {
  evaluatedPositionCount: 3,
  averageScore: 740,
  highLevelCount: 1,
  missingEvaluationCount: 0,
  maxTotalScore: 1000,
  evaluationFactors: [
    { key: 'knowledge', labelKey: 'jobEvaluationSetup.factors.knowledge', maxScore: 250 },
    { key: 'problem', labelKey: 'jobEvaluationSetup.factors.problem', maxScore: 250 },
    { key: 'responsibility', labelKey: 'jobEvaluationSetup.factors.responsibility', maxScore: 250 },
    { key: 'impact', labelKey: 'jobEvaluationSetup.factors.impact', maxScore: 250 },
  ],
  positions: [
    {
      id: 'je1',
      positionKey: 'jobEvaluationSetup.positions.hrManager',
      bandKey: 'jobEvaluationSetup.bands.level5',
      total: 855,
      factors: { knowledge: 220, problem: 200, responsibility: 240, impact: 195 },
    },
    {
      id: 'je2',
      positionKey: 'jobEvaluationSetup.positions.fieldEngineer',
      bandKey: 'jobEvaluationSetup.bands.level4',
      total: 720,
      factors: { knowledge: 200, problem: 190, responsibility: 170, impact: 160 },
    },
    {
      id: 'je3',
      positionKey: 'jobEvaluationSetup.positions.operationsSpecialist',
      bandKey: 'jobEvaluationSetup.bands.level3',
      total: 645,
      factors: { knowledge: 170, problem: 160, responsibility: 160, impact: 155 },
    },
  ],
  levelBands: [
    {
      id: 'lb5',
      levelKey: 'jobEvaluationSetup.bands.level5',
      rangeKey: 'jobEvaluationSetup.levelRanges.level5',
      noteKey: 'jobEvaluationSetup.levelNotes.management',
      tone: 'success',
    },
    {
      id: 'lb4',
      levelKey: 'jobEvaluationSetup.bands.level4',
      rangeKey: 'jobEvaluationSetup.levelRanges.level4',
      noteKey: 'jobEvaluationSetup.levelNotes.seniorExpert',
      tone: 'info',
    },
    {
      id: 'lb3',
      levelKey: 'jobEvaluationSetup.bands.level3',
      rangeKey: 'jobEvaluationSetup.levelRanges.level3',
      noteKey: 'jobEvaluationSetup.levelNotes.expert',
      tone: 'neutral',
    },
  ],
}

export async function fetchDemoJobEvaluationOverview(): Promise<DemoJobEvaluationOverview> {
  return demoJobEvaluationOverview
}

export type DemoContractSignedStatus = 'signed' | 'pending'

export type DemoContractRiskStatus = 'ok' | 'expiring' | 'pending'

export type DemoContractItem = {
  id: string
  employeeName: string
  initials: string
  typeKey: string
  startDate: string
  endDate: string | null
  signed: DemoContractSignedStatus
  risk: DemoContractRiskStatus
}

export type DemoContractsOverview = {
  activeContractCount: number
  expiringSoonCount: number
  pendingSignatureCount: number
  kvkkMissingCount: number
  contracts: DemoContractItem[]
}

const demoContractsOverview: DemoContractsOverview = {
  activeContractCount: 4,
  expiringSoonCount: 1,
  pendingSignatureCount: 1,
  kvkkMissingCount: 0,
  contracts: [
    {
      id: 'c1',
      employeeName: 'Ayşe Kaya',
      initials: 'AK',
      typeKey: 'contractsSetup.types.indefinite',
      startDate: '2024-03-04',
      endDate: null,
      signed: 'signed',
      risk: 'ok',
    },
    {
      id: 'c2',
      employeeName: 'Murat Tan',
      initials: 'MT',
      typeKey: 'contractsSetup.types.fixedTerm',
      startDate: '2022-09-18',
      endDate: '2026-07-05',
      signed: 'signed',
      risk: 'expiring',
    },
    {
      id: 'c3',
      employeeName: 'Elif Demir',
      initials: 'ED',
      typeKey: 'contractsSetup.types.probation',
      startDate: '2026-02-01',
      endDate: '2026-08-01',
      signed: 'pending',
      risk: 'pending',
    },
    {
      id: 'c4',
      employeeName: 'Demo İK Yöneticisi',
      initials: 'DY',
      typeKey: 'contractsSetup.types.indefinite',
      startDate: '2023-01-12',
      endDate: null,
      signed: 'signed',
      risk: 'ok',
    },
  ],
}

export async function fetchDemoContractsOverview(): Promise<DemoContractsOverview> {
  return demoContractsOverview
}

export type DemoAiCoachReadinessStatus = 'done' | 'pending'

export type DemoAiCoachCapability = {
  id: string
  titleKey: string
  descKey: string
}

export type DemoAiCoachReadinessItem = {
  id: string
  labelKey: string
  status: DemoAiCoachReadinessStatus
}

export type DemoAiCoachOverview = {
  capabilities: DemoAiCoachCapability[]
  readiness: DemoAiCoachReadinessItem[]
}

const demoAiCoachOverview: DemoAiCoachOverview = {
  capabilities: [
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
  ],
  readiness: [
    {
      id: 'r1',
      labelKey: 'aiCoachSetup.readiness.vaultSchema',
      status: 'done',
    },
    {
      id: 'r2',
      labelKey: 'aiCoachSetup.readiness.toolCallLayer',
      status: 'pending',
    },
    {
      id: 'r3',
      labelKey: 'aiCoachSetup.readiness.erpContext',
      status: 'pending',
    },
  ],
}

export async function fetchDemoAiCoachOverview(): Promise<DemoAiCoachOverview> {
  return demoAiCoachOverview
}

export type DemoProfileActivity = {
  id: string
  who: string
  whatKey: string
  whatParams?: Record<string, string | number>
  whenKey: string
}

export type DemoProfileOverview = {
  fallbackEmail: string
  departmentKey: string
  positionKey: string
  roleKey: string
  statusKey: string
  leaveRemaining: number
  leaveTotal: number
  leaveHintKey: string
  pendingExpenseAmount: number
  pendingExpenseCount: number
  performanceCycleKey: string
  performanceHintKey: string
  recentActivities: DemoProfileActivity[]
}

const demoProfileOverview: DemoProfileOverview = {
  fallbackEmail: 'ik@mertteknik.com',
  departmentKey: 'profileSetup.fields.departmentValue',
  positionKey: 'profileSetup.fields.positionValue',
  roleKey: 'profileSetup.fields.roleValue',
  statusKey: 'profileSetup.status.active',
  leaveRemaining: 14,
  leaveTotal: 20,
  leaveHintKey: 'profileSetup.selfHr.leaveHint',
  pendingExpenseAmount: 2340,
  pendingExpenseCount: 2,
  performanceCycleKey: 'profileSetup.selfHr.performanceCycle',
  performanceHintKey: 'profileSetup.selfHr.performanceHint',
  recentActivities: [
    {
      id: 'a1',
      who: 'Ayşe Kaya',
      whatKey: 'profileSetup.activities.leaveRequest',
      whenKey: 'profileSetup.when.twoHoursAgo',
    },
    {
      id: 'a2',
      who: 'Murat Tan',
      whatKey: 'profileSetup.activities.expenseReport',
      whatParams: { amount: 840 },
      whenKey: 'profileSetup.when.fiveHoursAgo',
    },
    {
      id: 'a3',
      who: 'Sistem',
      whatKey: 'profileSetup.activities.erpRetry',
      whenKey: 'profileSetup.when.yesterday',
    },
    {
      id: 'a4',
      who: 'Elif Demir',
      whatKey: 'profileSetup.activities.profileUpdate',
      whenKey: 'profileSetup.when.yesterday',
    },
  ],
}

export async function fetchDemoProfileOverview(): Promise<DemoProfileOverview> {
  return demoProfileOverview
}

export type DemoSettingsSection = {
  id: string
  titleKey: string
  summaryKey: string
  actionKey: string
  sheetDescriptionKey: string
  sheetBodyKey: string
}

export type DemoSettingsOverview = {
  auditLogDays: number
  auditLogSensitiveCount: number
  sections: DemoSettingsSection[]
}

const demoSettingsOverview: DemoSettingsOverview = {
  auditLogDays: 30,
  auditLogSensitiveCount: 14,
  sections: [
    {
      id: 'accountSecurity',
      titleKey: 'settingsSetup.sections.accountSecurity.title',
      summaryKey: 'settingsSetup.sections.accountSecurity.summary',
      actionKey: 'settingsSetup.sections.accountSecurity.action',
      sheetDescriptionKey: 'settingsSetup.sections.accountSecurity.sheetDescription',
      sheetBodyKey: 'settingsSetup.sections.accountSecurity.sheetBody',
    },
    {
      id: 'tenant',
      titleKey: 'settingsSetup.sections.tenant.title',
      summaryKey: 'settingsSetup.sections.tenant.summary',
      actionKey: 'settingsSetup.sections.tenant.action',
      sheetDescriptionKey: 'settingsSetup.sections.tenant.sheetDescription',
      sheetBodyKey: 'settingsSetup.sections.tenant.sheetBody',
    },
    {
      id: 'notifications',
      titleKey: 'settingsSetup.sections.notifications.title',
      summaryKey: 'settingsSetup.sections.notifications.summary',
      actionKey: 'settingsSetup.sections.notifications.action',
      sheetDescriptionKey: 'settingsSetup.sections.notifications.sheetDescription',
      sheetBodyKey: 'settingsSetup.sections.notifications.sheetBody',
    },
    {
      id: 'locale',
      titleKey: 'settingsSetup.sections.locale.title',
      summaryKey: 'settingsSetup.sections.locale.summary',
      actionKey: 'settingsSetup.sections.locale.action',
      sheetDescriptionKey: 'settingsSetup.sections.locale.sheetDescription',
      sheetBodyKey: 'settingsSetup.sections.locale.sheetBody',
    },
    {
      id: 'theme',
      titleKey: 'settingsSetup.sections.theme.title',
      summaryKey: 'settingsSetup.sections.theme.summary',
      actionKey: 'settingsSetup.sections.theme.action',
      sheetDescriptionKey: 'settingsSetup.sections.theme.sheetDescription',
      sheetBodyKey: 'settingsSetup.sections.theme.sheetBody',
    },
    {
      id: 'roleAccess',
      titleKey: 'settingsSetup.sections.roleAccess.title',
      summaryKey: 'settingsSetup.sections.roleAccess.summary',
      actionKey: 'settingsSetup.sections.roleAccess.action',
      sheetDescriptionKey: 'settingsSetup.sections.roleAccess.sheetDescription',
      sheetBodyKey: 'settingsSetup.sections.roleAccess.sheetBody',
    },
  ],
}

export async function fetchDemoSettingsOverview(): Promise<DemoSettingsOverview> {
  return demoSettingsOverview
}

export type DemoDashboardQueueTone = 'warning' | 'info'

export type DemoDashboardQueueIcon = 'target' | 'plug' | 'calendarCheck' | 'receipt'

export type DemoDashboardQueueItem = {
  id: string
  titleKey: string
  metaKey: string
  to: '/performans' | '/erp' | '/izin' | '/masraf'
  tone: DemoDashboardQueueTone
  icon: DemoDashboardQueueIcon
}

export type DemoDashboardActivity = {
  id: string
  who: string
  whatKey: string
  whatParams?: Record<string, string | number>
  whenKey: string
}

export type DemoDashboardErpStatus = {
  statusLabelKey: string
  mappedFields: number
  totalFields: number
  lastAttemptKey: string
  readiness: number
  descriptionKey: string
}

export type DemoDashboardOverview = {
  positionCount: number
  queue: DemoDashboardQueueItem[]
  recentActivities: DemoDashboardActivity[]
  erpStatus: DemoDashboardErpStatus
}

const demoDashboardOverview: DemoDashboardOverview = {
  positionCount: 3,
  queue: [
    {
      id: 'q1',
      titleKey: 'dashboardSetup.queue.performancePeriod.title',
      metaKey: 'dashboardSetup.queue.performancePeriod.meta',
      to: '/performans',
      tone: 'info',
      icon: 'target',
    },
    {
      id: 'q2',
      titleKey: 'dashboardSetup.queue.fieldMapping.title',
      metaKey: 'dashboardSetup.queue.fieldMapping.meta',
      to: '/erp',
      tone: 'warning',
      icon: 'plug',
    },
    {
      id: 'q3',
      titleKey: 'dashboardSetup.queue.leaveApproval.title',
      metaKey: 'dashboardSetup.queue.leaveApproval.meta',
      to: '/izin',
      tone: 'warning',
      icon: 'calendarCheck',
    },
    {
      id: 'q4',
      titleKey: 'dashboardSetup.queue.expenseApproval.title',
      metaKey: 'dashboardSetup.queue.expenseApproval.meta',
      to: '/masraf',
      tone: 'warning',
      icon: 'receipt',
    },
  ],
  recentActivities: [
    {
      id: 'a1',
      who: 'Ayşe Kaya',
      whatKey: 'profileSetup.activities.leaveRequest',
      whenKey: 'profileSetup.when.twoHoursAgo',
    },
    {
      id: 'a2',
      who: 'Murat Tan',
      whatKey: 'profileSetup.activities.expenseReport',
      whatParams: { amount: 840 },
      whenKey: 'profileSetup.when.fiveHoursAgo',
    },
    {
      id: 'a3',
      who: 'Sistem',
      whatKey: 'profileSetup.activities.erpRetry',
      whenKey: 'profileSetup.when.yesterday',
    },
    {
      id: 'a4',
      who: 'Elif Demir',
      whatKey: 'profileSetup.activities.profileUpdate',
      whenKey: 'profileSetup.when.yesterday',
    },
  ],
  erpStatus: {
    statusLabelKey: 'dashboardSetup.erpCard.statusPending',
    mappedFields: 6,
    totalFields: 12,
    lastAttemptKey: 'dashboardSetup.erpCard.lastAttemptValue',
    readiness: 72,
    descriptionKey: 'dashboardSetup.erpCard.description',
  },
}

export async function fetchDemoDashboardOverview(): Promise<DemoDashboardOverview> {
  return demoDashboardOverview
}

export type DemoPerformanceTemplateDisplay = {
  areasCount: number
  updatedKey: string
}

export type DemoPerformanceOverview = {
  employeeScopeCount: number
  evaluatorCount: number
  pendingReviews: number
  completedThisWeek: number
  overdueCount: number
  defaultCycleName: string
  templateDisplayByIndex: DemoPerformanceTemplateDisplay[]
}

const demoPerformanceOverview: DemoPerformanceOverview = {
  employeeScopeCount: 4,
  evaluatorCount: 3,
  pendingReviews: 4,
  completedThisWeek: 0,
  overdueCount: 0,
  defaultCycleName: '2026 Q2',
  templateDisplayByIndex: [
    { areasCount: 6, updatedKey: 'performanceSetup.templates.updatedApr12' },
    { areasCount: 5, updatedKey: 'performanceSetup.templates.updatedApr8' },
    { areasCount: 7, updatedKey: 'performanceSetup.templates.updatedMar1' },
  ],
}

export async function fetchDemoPerformanceOverview(): Promise<DemoPerformanceOverview> {
  return demoPerformanceOverview
}

export type DemoEmployeeStatus = 'active' | 'onleave' | 'inactive'

export type DemoEmployeeFallback = {
  status?: DemoEmployeeStatus
  manager?: string
  leaveUsed?: number
  leaveTotal?: number
  joinedLabel?: string
}

export type DemoEmployeesOverview = {
  defaultStatus: DemoEmployeeStatus
  defaultManager: string
  defaultLeave: { used: number; total: number }
  performanceScopePendingKey: string
  byEmail: Record<string, DemoEmployeeFallback>
}

const demoEmployeesOverview: DemoEmployeesOverview = {
  defaultStatus: 'active',
  defaultManager: '—',
  defaultLeave: { used: 0, total: 20 },
  performanceScopePendingKey: 'employeesSetup.detail.performancePending',
  byEmail: {
    'ik@mertteknik.com': {
      status: 'active',
      manager: '—',
      leaveUsed: 6,
      leaveTotal: 20,
      joinedLabel: '12 Oca 2023',
    },
    'ayse.kaya@mertteknik.com': {
      status: 'onleave',
      manager: 'Murat Tan',
      leaveUsed: 8,
      leaveTotal: 14,
      joinedLabel: '04 Mar 2024',
    },
    'murat.tan@mertteknik.com': {
      status: 'active',
      manager: 'Demo İK Yöneticisi',
      leaveUsed: 4,
      leaveTotal: 18,
      joinedLabel: '18 Eyl 2022',
    },
    'elif.demir@mertteknik.com': {
      status: 'active',
      manager: 'Demo İK Yöneticisi',
      leaveUsed: 2,
      leaveTotal: 14,
      joinedLabel: '01 Şub 2025',
    },
  },
}

export async function fetchDemoEmployeesOverview(): Promise<DemoEmployeesOverview> {
  return demoEmployeesOverview
}
