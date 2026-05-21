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

/** Parse decimal input accepting comma or dot separators. */
export function parseDecimalAmount(raw: string): number {
  const normalized = raw.trim().replace(/\s/g, '').replace(',', '.')
  if (!normalized) return NaN
  return Number(normalized)
}

export function formatCurrency(amount: number, locale = 'tr-TR', currency = 'TRY'): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    maximumFractionDigits: 0,
  }).format(amount)
}
