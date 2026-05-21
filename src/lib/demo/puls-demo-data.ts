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
