import type { PersonaRole } from '#/lib/supabase'

type SalaryViewerRole = PersonaRole | 'payroll_admin'

export function maskSalary(
  viewerRole: SalaryViewerRole,
  targetEmployeeId: string,
  viewerEmployeeId: string,
  amount: number,
  currency = 'TRY',
): string {
  if (viewerRole === 'payroll_admin' || viewerRole === 'hr_admin') {
    return formatMoney(amount, currency)
  }

  if (viewerRole === 'employee' && targetEmployeeId === viewerEmployeeId) {
    return formatMoney(amount, currency)
  }

  if (viewerRole === 'manager') {
    return `₺•••.${String(Math.floor(amount % 1000)).padStart(3, '0')} [Görüntüle]`
  }

  return '—'
}

function formatMoney(amount: number, currency: string) {
  return new Intl.NumberFormat('tr-TR', {
    style: 'currency',
    currency,
    maximumFractionDigits: 0,
  }).format(amount)
}
