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
