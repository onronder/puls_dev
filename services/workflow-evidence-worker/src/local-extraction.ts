export type LocalReceiptFieldKey =
  | 'merchant_name'
  | 'receipt_date'
  | 'total_amount'
  | 'currency'
  | 'tax_amount'
  | 'receipt_number'

export type LocalReceiptExtractionFields = Partial<
  Record<LocalReceiptFieldKey, string | number | null>
>

export type LocalReceiptExtraction = {
  routeUsed: 'pdf_text' | 'no_text_layer'
  fields: LocalReceiptExtractionFields
  fieldConfidence: Partial<Record<LocalReceiptFieldKey, number>>
  documentConfidence: number
  warnings: string[]
}

const TEXT_DECODER = new TextDecoder('latin1')
const MAX_TEXT_CHARS = 20_000
const MIN_TEXT_LAYER_CHARS = 24
const CURRENCY_PATTERN = /\b(TRY|TL|TRL|USD|EUR)\b|₺|\$|€/iu
const DATE_PATTERN = /\b([0-3]?\d)[./-]([01]?\d)[./-](20\d{2})\b/u
const AMOUNT_PATTERN = /-?\d{1,3}(?:\.\d{3})*(?:,\d{2})|-?\d+(?:,\d{2})|-?\d+\.\d{2}/u

const TOTAL_LABEL_PATTERN = /\b(GENEL\s+TOPLAM|TOPLAM|TOTAL)\b/iu
const TAX_LABEL_PATTERN = /\b(TOPKDV|TOPLAM\s+KDV|KDV)\b/iu
const RECEIPT_NUMBER_PATTERN =
  /\b(FIS|FİŞ|BELGE|FATURA)\s*(NO|NUMARASI|#)?\s*[:.-]?\s*([A-Z0-9-]{3,})\b/iu
const NON_TOTAL_LABEL_PATTERN =
  /\b(ARA\s+TOPLAM|TOPKDV|TOPLAM\s+KDV|KDV|NAKIT|NAKİT|KREDI|KREDİ|PARA\s+USTU|PARA\s+ÜSTÜ)\b/iu

function normalizeWhitespace(value: string) {
  return value.replace(/\s+/g, ' ').trim()
}

function normalizeLine(value: string) {
  return normalizeWhitespace(value.split(String.fromCharCode(0)).join(''))
}

function isLikelyPdf(bytes: Uint8Array) {
  return TEXT_DECODER.decode(bytes.slice(0, 5)) === '%PDF-'
}

function unescapePdfLiteral(value: string) {
  return value
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\\(/g, '(')
    .replace(/\\\)/g, ')')
    .replace(/\\\\/g, '\\')
}

function extractPdfLiteralStrings(pdfText: string) {
  const parts: string[] = []
  const literalPattern = /\((?:\\.|[^\\)]){2,}\)\s*Tj|\((?:\\.|[^\\)]){2,}\)\s*'/g
  for (const match of pdfText.matchAll(literalPattern)) {
    const literal = match[0].match(/\((.*)\)/s)?.[1]
    if (literal) parts.push(unescapePdfLiteral(literal))
  }

  const arrayTextPattern = /\[(.*?)\]\s*TJ/gs
  for (const arrayMatch of pdfText.matchAll(arrayTextPattern)) {
    for (const literalMatch of arrayMatch[1].matchAll(/\((?:\\.|[^\\)]){2,}\)/g)) {
      const literal = literalMatch[0].slice(1, -1)
      parts.push(unescapePdfLiteral(literal))
    }
  }

  return parts.join('\n')
}

function normalizeExtractedText(value: string) {
  return value.split(/\r?\n/u).map(normalizeLine).filter(Boolean).join('\n')
}

export function extractPdfTextLayer(bytes: Uint8Array, mimeType: string | null | undefined) {
  const decoded = TEXT_DECODER.decode(bytes).slice(0, MAX_TEXT_CHARS)
  if (mimeType?.toLowerCase().includes('pdf') || isLikelyPdf(bytes)) {
    return normalizeExtractedText(extractPdfLiteralStrings(decoded))
  }

  if (mimeType?.toLowerCase().startsWith('text/')) {
    return normalizeExtractedText(decoded)
  }

  return ''
}

export function parseTurkishAmount(value: string): number | null {
  const amount = value.match(AMOUNT_PATTERN)?.[0]
  if (!amount) return null

  const normalized = amount.includes(',') ? amount.replace(/\./g, '').replace(',', '.') : amount

  const parsed = Number(normalized)
  if (!Number.isFinite(parsed)) return null
  return Math.round(parsed * 100) / 100
}

export function normalizeTurkishReceiptDate(value: string): string | null {
  const match = value.match(DATE_PATTERN)
  if (!match) return null

  const day = Number(match[1])
  const month = Number(match[2])
  const year = Number(match[3])
  const date = new Date(Date.UTC(year, month - 1, day))
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null
  }

  return `${year.toString().padStart(4, '0')}-${month.toString().padStart(2, '0')}-${day
    .toString()
    .padStart(2, '0')}`
}

export function normalizeReceiptCurrency(value: string): 'TRY' | 'USD' | 'EUR' | null {
  const match = value.match(CURRENCY_PATTERN)?.[0]?.toLocaleUpperCase('tr-TR')
  if (!match) return null
  if (match === 'TRY' || match === 'TL' || match === 'TRL' || match === '₺') return 'TRY'
  if (match === 'USD' || match === '$') return 'USD'
  if (match === 'EUR' || match === '€') return 'EUR'
  return null
}

function findAmountByLabel(lines: string[], labelPattern: RegExp, excludePattern?: RegExp) {
  for (const line of lines) {
    if (!labelPattern.test(line)) continue
    if (excludePattern?.test(line)) continue
    const amount = parseTurkishAmount(line)
    if (amount !== null) return amount
  }
  return null
}

function findMerchantName(lines: string[]) {
  for (const line of lines.slice(0, 6)) {
    if (line.length < 3) continue
    if (DATE_PATTERN.test(line) || AMOUNT_PATTERN.test(line) || TOTAL_LABEL_PATTERN.test(line))
      continue
    if (TAX_LABEL_PATTERN.test(line) || RECEIPT_NUMBER_PATTERN.test(line)) continue
    return line.slice(0, 120)
  }
  return null
}

function findReceiptNumber(lines: string[]) {
  for (const line of lines) {
    const match = line.match(RECEIPT_NUMBER_PATTERN)
    if (match?.[3]) return match[3].slice(0, 64)
  }
  return null
}

export function extractReceiptFieldsFromText(text: string): LocalReceiptExtraction {
  const normalizedText = normalizeWhitespace(text)
  const lines = text
    .split(/\r?\n| {2,}/u)
    .map(normalizeLine)
    .filter(Boolean)

  if (normalizedText.length < MIN_TEXT_LAYER_CHARS || lines.length === 0) {
    return {
      routeUsed: 'no_text_layer',
      fields: {},
      fieldConfidence: {},
      documentConfidence: 0,
      warnings: ['no_text_layer', 'human_review_required'],
    }
  }

  const fields: LocalReceiptExtractionFields = {}
  const fieldConfidence: Partial<Record<LocalReceiptFieldKey, number>> = {}
  const warnings: string[] = ['human_review_required']

  const merchantName = findMerchantName(lines)
  if (merchantName) {
    fields.merchant_name = merchantName
    fieldConfidence.merchant_name = 0.65
  }

  const receiptDate = normalizeTurkishReceiptDate(normalizedText)
  if (receiptDate) {
    fields.receipt_date = receiptDate
    fieldConfidence.receipt_date = 0.8
  } else {
    warnings.push('receipt_date_missing')
  }

  const totalAmount = findAmountByLabel(lines, TOTAL_LABEL_PATTERN, NON_TOTAL_LABEL_PATTERN)
  if (totalAmount !== null) {
    fields.total_amount = totalAmount
    fieldConfidence.total_amount = 0.75
  } else {
    warnings.push('total_amount_missing')
  }

  const taxAmount = findAmountByLabel(lines, TAX_LABEL_PATTERN)
  if (taxAmount !== null) {
    fields.tax_amount = taxAmount
    fieldConfidence.tax_amount = 0.65
  }

  const currency = normalizeReceiptCurrency(normalizedText) ?? 'TRY'
  fields.currency = currency
  fieldConfidence.currency = normalizeReceiptCurrency(normalizedText) ? 0.7 : 0.45

  const receiptNumber = findReceiptNumber(lines)
  if (receiptNumber) {
    fields.receipt_number = receiptNumber
    fieldConfidence.receipt_number = 0.6
  }

  if (totalAmount !== null && taxAmount !== null && taxAmount > totalAmount) {
    warnings.push('tax_amount_exceeds_total')
  }

  const scoredFields = Object.keys(fieldConfidence).length
  const documentConfidence = Math.min(0.78, Math.max(0.35, scoredFields / 8 + 0.25))

  return {
    routeUsed: 'pdf_text',
    fields,
    fieldConfidence,
    documentConfidence,
    warnings,
  }
}

export function extractReceiptFieldsFromPdfTextLayer(
  bytes: Uint8Array,
  mimeType: string | null | undefined,
) {
  return extractReceiptFieldsFromText(extractPdfTextLayer(bytes, mimeType))
}
