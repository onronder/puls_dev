/** Count Mon–Fri inclusive between two ISO date strings (YYYY-MM-DD). */
export function countBusinessDays(startDate: string, endDate: string): number {
  if (!startDate || !endDate) return 0

  const start = new Date(`${startDate}T12:00:00`)
  const end = new Date(`${endDate}T12:00:00`)
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end < start) {
    return 0
  }

  let count = 0
  const cursor = new Date(start)
  while (cursor <= end) {
    const day = cursor.getDay()
    if (day !== 0 && day !== 6) count += 1
    cursor.setDate(cursor.getDate() + 1)
  }
  return count
}

/** Parse decimal input accepting TR/EU comma formats and plain dot decimals. */
export function parseDecimalAmount(raw: string): number {
  const trimmed = raw.trim().replace(/\s/g, '')
  if (!trimmed) return NaN

  const hasComma = trimmed.includes(',')
  const hasDot = trimmed.includes('.')

  if (hasComma && hasDot) {
    if (trimmed.lastIndexOf(',') > trimmed.lastIndexOf('.')) {
      return Number(trimmed.replace(/\./g, '').replace(',', '.'))
    }
    return Number(trimmed.replace(/,/g, ''))
  }

  if (hasComma) {
    return Number(trimmed.replace(',', '.'))
  }

  if (hasDot) {
    const parts = trimmed.split('.')
    if (parts.length === 2 && parts[1].length <= 2) {
      return Number(trimmed)
    }
    return Number(trimmed.replace(/\./g, ''))
  }

  return Number(trimmed)
}

export function formatCurrency(amount: number, locale = 'tr-TR', currency = 'TRY'): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    maximumFractionDigits: 0,
  }).format(amount)
}
