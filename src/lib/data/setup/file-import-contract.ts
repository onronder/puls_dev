export const FILE_IMPORT_TEMPLATE_VERSION = 'v1'
export const FILE_IMPORT_TIMEZONE = 'Europe/Istanbul'
export const FILE_IMPORT_MAX_ROWS = 5000
export const FILE_IMPORT_MAX_CSV_BYTES = 5 * 1024 * 1024
export const FILE_IMPORT_MAX_XLSX_BYTES = 10 * 1024 * 1024

export type FileImportScopeId =
  | 'employees'
  | 'departments'
  | 'positions'
  | 'legal_entities'
  | 'locations'
  | 'cost_centers'

export type FileImportEntityType =
  | 'employee'
  | 'department'
  | 'position'
  | 'legal_entity'
  | 'location'
  | 'cost_center'

export type FileImportColumnType = 'text' | 'email' | 'date' | 'boolean' | 'integer'
export type FileImportIssueLevel = 'error' | 'warning'

export type FileImportIssue = {
  level: FileImportIssueLevel
  code: string
  rowNumber?: number
  column?: string
  detail?: string
}

export type FileImportColumn = {
  key: string
  labelKey: string
  type: FileImportColumnType
  required: boolean
  aliases?: string[]
}

export type FileImportScopeContract = {
  id: FileImportScopeId
  entityType: FileImportEntityType
  labelKey: string
  fileStem: string
  externalIdField: string
  columns: FileImportColumn[]
}

export type FileImportParsedRow = {
  rowNumber: number
  entityType: FileImportEntityType
  externalId: string
  payload: Record<string, string | number | boolean | null>
}

export type FileImportParseResult = {
  ok: boolean
  scope: FileImportScopeId
  fileName: string
  fileExtension: 'csv' | 'xlsx' | null
  fileSizeBytes: number
  fileChecksum: string | null
  templateVersion: typeof FILE_IMPORT_TEMPLATE_VERSION
  businessDate: string | null
  delimiter: ',' | ';' | '\t' | null
  rowCount: number
  rows: FileImportParsedRow[]
  mappedColumns: Array<{
    sourceHeader: string
    targetField: string
    required: boolean
    type: FileImportColumnType
  }>
  ignoredHeaders: string[]
  issues: FileImportIssue[]
}

export type FileImportPackageItem = {
  scope: FileImportScopeId | null
  fileName: string
  parseResult: FileImportParseResult
}

export type FileImportPackageResult = {
  ok: boolean
  packageId: string
  files: FileImportPackageItem[]
  fileCount: number
  readyFileCount: number
  blockedFileCount: number
  rowCount: number
  issues: FileImportIssue[]
}

type TableCell = string | number | boolean | Date | null

type ParsedTable = {
  rows: TableCell[][]
  delimiter: ',' | ';' | '\t' | null
  issues: FileImportIssue[]
}

type ExcelCellValue = import('exceljs').CellValue
type ExcelFormulaValue =
  | import('exceljs').CellFormulaValue
  | import('exceljs').CellSharedFormulaValue
type ExcelWorksheet = import('exceljs').Worksheet

const COMMON_BOOLEAN_TRUE = new Set(['true', '1', 'yes', 'evet', 'aktif', 'active'])
const COMMON_BOOLEAN_FALSE = new Set(['false', '0', 'no', 'hayir', 'hayır', 'pasif', 'inactive'])
const NULL_LITERALS = new Set(['null', '(null)'])
const FILE_IMPORT_SCOPE_ORDER: FileImportScopeId[] = [
  'legal_entities',
  'locations',
  'cost_centers',
  'departments',
  'positions',
  'employees',
]

const BLOCKED_HEADER_PATTERNS = [
  'salary',
  'salary_min',
  'salary_max',
  'maas',
  'maaş',
  'ucret',
  'ücret',
  'pay_band',
  'payroll',
  'compensation',
  'tckn',
  'tc_kimlik',
  'iban',
  'health',
  'saglik',
  'sağlık',
  'family',
  'aile',
]

export const FILE_IMPORT_SCOPE_CONTRACTS: Record<FileImportScopeId, FileImportScopeContract> = {
  employees: {
    id: 'employees',
    entityType: 'employee',
    labelKey: 'erp.fileImport.scopes.employees',
    fileStem: 'employees',
    externalIdField: 'employee_code',
    columns: [
      column('employee_code', 'text', true, ['calisan_kodu', 'çalışan_kodu', 'sicil_no']),
      column('full_name', 'text', true, ['ad_soyad', 'isim', 'çalışan_adı', 'calisan_adi']),
      column('email', 'email', false, ['e_posta', 'eposta']),
      column('job_title', 'text', false, ['unvan', 'gorev', 'görev']),
      column('employment_status', 'text', false, ['calisma_durumu', 'çalışma_durumu']),
      column('hire_date', 'date', false, ['ise_giris_tarihi', 'işe_giriş_tarihi']),
      column('termination_date', 'date', false, ['isten_cikis_tarihi', 'işten_çıkış_tarihi']),
      column('department_code', 'text', false, ['departman_kodu']),
      column('position_code', 'text', false, ['pozisyon_kodu']),
      column('manager_employee_code', 'text', false, ['yonetici_kodu', 'yönetici_kodu']),
      column('manager_email', 'email', false, ['yonetici_email', 'yönetici_eposta']),
      column('legal_entity_code', 'text', false, ['sirket_kodu', 'şirket_kodu']),
      column('location_code', 'text', false, ['lokasyon_kodu']),
      column('cost_center_code', 'text', false, ['maliyet_merkezi_kodu']),
    ],
  },
  departments: {
    id: 'departments',
    entityType: 'department',
    labelKey: 'erp.fileImport.scopes.departments',
    fileStem: 'departments',
    externalIdField: 'code',
    columns: [
      column('code', 'text', true, ['departman_kodu']),
      column('name', 'text', true, ['departman_adi', 'departman_adı']),
      column('is_active', 'boolean', false, ['aktif']),
      column('parent_department_code', 'text', false, ['ust_departman_kodu', 'üst_departman_kodu']),
      column('manager_employee_code', 'text', false, ['yonetici_kodu', 'yönetici_kodu']),
      column('manager_email', 'email', false, ['yonetici_email', 'yönetici_eposta']),
      column('cost_center_code', 'text', false, ['maliyet_merkezi_kodu']),
    ],
  },
  positions: {
    id: 'positions',
    entityType: 'position',
    labelKey: 'erp.fileImport.scopes.positions',
    fileStem: 'positions',
    externalIdField: 'code',
    columns: [
      column('code', 'text', true, ['pozisyon_kodu']),
      column('name', 'text', true, ['pozisyon_adi', 'pozisyon_adı']),
      column('is_active', 'boolean', false, ['aktif']),
      column('department_code', 'text', false, ['departman_kodu']),
      column('parent_position_code', 'text', false, ['ust_pozisyon_kodu', 'üst_pozisyon_kodu']),
      column('level', 'text', false, ['seviye']),
      column('norm_headcount', 'integer', false, ['norm_kadro']),
      column('employment_type', 'text', false, ['calisma_tipi', 'çalışma_tipi']),
    ],
  },
  legal_entities: {
    id: 'legal_entities',
    entityType: 'legal_entity',
    labelKey: 'erp.fileImport.scopes.legal_entities',
    fileStem: 'legal_entities',
    externalIdField: 'code',
    columns: [
      column('code', 'text', true, ['sirket_kodu', 'şirket_kodu']),
      column('name', 'text', true, ['sirket_adi', 'şirket_adı']),
      column('is_active', 'boolean', false, ['aktif']),
    ],
  },
  locations: {
    id: 'locations',
    entityType: 'location',
    labelKey: 'erp.fileImport.scopes.locations',
    fileStem: 'locations',
    externalIdField: 'code',
    columns: [
      column('code', 'text', true, ['lokasyon_kodu']),
      column('name', 'text', true, ['lokasyon_adi', 'lokasyon_adı']),
      column('is_active', 'boolean', false, ['aktif']),
      column('legal_entity_code', 'text', true, ['sirket_kodu', 'şirket_kodu']),
    ],
  },
  cost_centers: {
    id: 'cost_centers',
    entityType: 'cost_center',
    labelKey: 'erp.fileImport.scopes.cost_centers',
    fileStem: 'cost_centers',
    externalIdField: 'code',
    columns: [
      column('code', 'text', true, ['maliyet_merkezi_kodu']),
      column('name', 'text', true, ['maliyet_merkezi_adi', 'maliyet_merkezi_adı']),
      column('is_active', 'boolean', false, ['aktif']),
      column('legal_entity_code', 'text', true, ['sirket_kodu', 'şirket_kodu']),
      column('parent_cost_center_code', 'text', false, [
        'ust_maliyet_merkezi_kodu',
        'üst_maliyet_merkezi_kodu',
      ]),
    ],
  },
}

function column(
  key: string,
  type: FileImportColumnType,
  required: boolean,
  aliases: string[] = [],
): FileImportColumn {
  return {
    key,
    type,
    required,
    aliases,
    labelKey: `erp.fileImport.columns.${key}`,
  }
}

export function fileImportScopeOptions(): FileImportScopeContract[] {
  return FILE_IMPORT_SCOPE_ORDER.map((scope) => FILE_IMPORT_SCOPE_CONTRACTS[scope])
}

export function fileImportScopeRank(scope: FileImportScopeId | null | undefined): number {
  if (!scope) return 999
  const index = FILE_IMPORT_SCOPE_ORDER.indexOf(scope)
  return index === -1 ? 999 : index
}

export function getFileImportScopeContract(scope: FileImportScopeId): FileImportScopeContract {
  return FILE_IMPORT_SCOPE_CONTRACTS[scope]
}

export function buildFileImportExpectedFileName(
  scope: FileImportScopeId,
  date = new Date(),
  extension: 'csv' | 'xlsx' = 'csv',
): string {
  const businessDate = formatBusinessDate(date)
  return `puls_${scope}_${FILE_IMPORT_TEMPLATE_VERSION}_${businessDate}.${extension}`
}

export function buildFileImportCsvTemplate(scope: FileImportScopeId): string {
  const contract = getFileImportScopeContract(scope)
  const headers = contract.columns.map((col) => escapeCsvValue(col.key)).join(',')
  return `\uFEFF${headers}\n`
}

export function buildFileImportPackageId(): string {
  return crypto.randomUUID()
}

export function inferFileImportScopeFromFileName(fileName: string): FileImportScopeId | null {
  const match = /^puls_([a-z_]+)_v1_\d{8}\.(?:csv|xlsx)$/i.exec(fileName.trim())
  const scope = match?.[1] as FileImportScopeId | undefined
  return scope && scope in FILE_IMPORT_SCOPE_CONTRACTS ? scope : null
}

export async function parseFileImport(
  file: File,
  scope: FileImportScopeId,
): Promise<FileImportParseResult> {
  const contract = getFileImportScopeContract(scope)
  const extension = fileExtension(file.name)
  const checksum = await sha256File(file)
  const issues: FileImportIssue[] = []
  const fileNameMeta = validateFileName(file.name, scope)
  issues.push(...fileNameMeta.issues)

  if (extension !== 'csv' && extension !== 'xlsx') {
    issues.push({ level: 'error', code: 'UNSUPPORTED_FILE_TYPE', detail: file.name })
  } else {
    const maxBytes = extension === 'csv' ? FILE_IMPORT_MAX_CSV_BYTES : FILE_IMPORT_MAX_XLSX_BYTES
    if (file.size > maxBytes) {
      issues.push({
        level: 'error',
        code: 'FILE_TOO_LARGE',
        detail: `${file.size}/${maxBytes}`,
      })
    }
  }

  if (issues.some((issue) => issue.level === 'error')) {
    return emptyParseResult(file, scope, extension, checksum, fileNameMeta.businessDate, issues)
  }

  const parsed = extension === 'csv' ? await parseCsvFile(file) : await parseXlsxFile(file)
  issues.push(...parsed.issues)

  const tableResult = normalizeTableRows(parsed.rows, contract)
  issues.push(...tableResult.issues)

  return {
    ok: issues.every((issue) => issue.level !== 'error'),
    scope,
    fileName: file.name,
    fileExtension: extension,
    fileSizeBytes: file.size,
    fileChecksum: checksum,
    templateVersion: FILE_IMPORT_TEMPLATE_VERSION,
    businessDate: fileNameMeta.businessDate,
    delimiter: parsed.delimiter,
    rowCount: tableResult.rows.length,
    rows: tableResult.rows,
    mappedColumns: tableResult.mappedColumns,
    ignoredHeaders: tableResult.ignoredHeaders,
    issues,
  }
}

export async function parseFileImportPackage(
  files: File[],
  allowedScopes: FileImportScopeId[] = FILE_IMPORT_SCOPE_ORDER,
  packageId = buildFileImportPackageId(),
): Promise<FileImportPackageResult> {
  const allowedScopeSet = new Set(allowedScopes)
  const issues: FileImportIssue[] = []
  if (files.length === 0) {
    issues.push({ level: 'error', code: 'PACKAGE_FILE_REQUIRED' })
  }
  if (files.length > allowedScopes.length) {
    issues.push({
      level: 'error',
      code: 'PACKAGE_TOO_MANY_FILES',
      detail: `${files.length}/${allowedScopes.length}`,
    })
  }

  const parsedFiles: FileImportPackageItem[] = []
  for (const file of files) {
    const inferredScope = inferFileImportScopeFromFileName(file.name)
    if (!inferredScope) {
      parsedFiles.push({
        scope: null,
        fileName: file.name,
        parseResult: emptyParseResult(file, 'employees', fileExtension(file.name), null, null, [
          { level: 'error', code: 'INVALID_FILE_NAME', detail: file.name },
        ]),
      })
      continue
    }
    if (!allowedScopeSet.has(inferredScope)) {
      parsedFiles.push({
        scope: inferredScope,
        fileName: file.name,
        parseResult: addIssueToParseResult(await parseFileImport(file, inferredScope), {
          level: 'error',
          code: 'FILE_SCOPE_NOT_ALLOWED',
          detail: inferredScope,
        }),
      })
      continue
    }
    parsedFiles.push({
      scope: inferredScope,
      fileName: file.name,
      parseResult: await parseFileImport(file, inferredScope),
    })
  }

  const seenScopes = new Map<FileImportScopeId, number>()
  const filesWithPackageChecks = parsedFiles.map((item) => {
    if (!item.scope) return item
    const previousCount = seenScopes.get(item.scope) ?? 0
    seenScopes.set(item.scope, previousCount + 1)
    if (previousCount === 0) return item
    return {
      ...item,
      parseResult: addIssueToParseResult(item.parseResult, {
        level: 'error',
        code: 'DUPLICATE_SCOPE_IN_PACKAGE',
        detail: item.scope,
      }),
    }
  })

  const orderedFiles = filesWithPackageChecks.sort((left, right) => {
    const leftIndex = fileImportScopeRank(left.scope)
    const rightIndex = fileImportScopeRank(right.scope)
    return leftIndex - rightIndex || left.fileName.localeCompare(right.fileName, 'tr')
  })
  const fileIssues = orderedFiles.flatMap((item) => item.parseResult.issues)
  const allIssues = [...issues, ...fileIssues]

  return {
    ok: allIssues.every((issue) => issue.level !== 'error'),
    packageId,
    files: orderedFiles,
    fileCount: orderedFiles.length,
    readyFileCount: orderedFiles.filter((item) => item.parseResult.ok).length,
    blockedFileCount: orderedFiles.filter((item) => !item.parseResult.ok).length,
    rowCount: orderedFiles.reduce((sum, item) => sum + item.parseResult.rowCount, 0),
    issues: allIssues,
  }
}

function emptyParseResult(
  file: File,
  scope: FileImportScopeId,
  extension: 'csv' | 'xlsx' | null,
  checksum: string | null,
  businessDate: string | null,
  issues: FileImportIssue[],
): FileImportParseResult {
  return {
    ok: false,
    scope,
    fileName: file.name,
    fileExtension: extension,
    fileSizeBytes: file.size,
    fileChecksum: checksum,
    templateVersion: FILE_IMPORT_TEMPLATE_VERSION,
    businessDate,
    delimiter: null,
    rowCount: 0,
    rows: [],
    mappedColumns: [],
    ignoredHeaders: [],
    issues,
  }
}

function addIssueToParseResult(
  result: FileImportParseResult,
  issue: FileImportIssue,
): FileImportParseResult {
  return {
    ...result,
    ok: false,
    issues: [...result.issues, issue],
  }
}

async function parseCsvFile(file: File): Promise<ParsedTable> {
  const Papa = (await import('papaparse')).default
  const text = stripBom(await file.text())
  const delimiter = detectDelimiter(text)
  const result = Papa.parse<string[]>(text, {
    delimiter,
    skipEmptyLines: false,
  })
  const issues: FileImportIssue[] = result.errors.map((error) => ({
    level: 'error',
    code: 'CSV_PARSE_ERROR',
    rowNumber: typeof error.row === 'number' ? error.row + 1 : undefined,
    detail: error.message,
  }))

  return {
    rows: (result.data ?? []).map((row) => row.map((cell) => cell ?? null)),
    delimiter,
    issues,
  }
}

async function parseXlsxFile(file: File): Promise<ParsedTable> {
  const ExcelJS = (await import('exceljs')).default
  const buffer = await file.arrayBuffer()
  const workbook = new ExcelJS.Workbook()
  await workbook.xlsx.load(buffer)
  const sheet = workbook.worksheets[0]
  if (!sheet) {
    return {
      rows: [],
      delimiter: null,
      issues: [{ level: 'error', code: 'XLSX_EMPTY_WORKBOOK' }],
    }
  }

  return {
    rows: excelWorksheetToRows(sheet),
    delimiter: null,
    issues: collectFormulaIssues(sheet),
  }
}

function collectFormulaIssues(sheet: ExcelWorksheet): FileImportIssue[] {
  const issues: FileImportIssue[] = []
  sheet.eachRow({ includeEmpty: false }, (row, rowNumber) => {
    row.eachCell({ includeEmpty: false }, (cell) => {
      const value = cell.value
      if (!isExcelFormulaValue(value)) return
      if (value.result === undefined || value.result === null) {
        issues.push({
          level: 'error',
          code: 'XLSX_FORMULA_VALUE_MISSING',
          rowNumber,
          column: cell.address,
        })
      }
    })
  })
  return issues
}

function excelWorksheetToRows(sheet: ExcelWorksheet): TableCell[][] {
  const rows: TableCell[][] = []
  const columnCount = sheet.columnCount
  for (let rowNumber = 1; rowNumber <= sheet.rowCount; rowNumber += 1) {
    const row = sheet.getRow(rowNumber)
    const values: TableCell[] = []
    for (let colNumber = 1; colNumber <= columnCount; colNumber += 1) {
      values.push(excelCellValueToTableCell(row.getCell(colNumber).value))
    }
    if (values.some((value) => normalizeCellText(value) !== null)) {
      rows.push(values)
    }
  }
  return rows
}

function excelCellValueToTableCell(value: ExcelCellValue): TableCell {
  if (value === null || value === undefined) return null
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') return value
  if (value instanceof Date) return value
  if (isExcelFormulaValue(value)) return excelCellValueToTableCell(value.result)
  if ('text' in value && typeof value.text === 'string') return value.text
  if ('richText' in value && Array.isArray(value.richText)) {
    const text = value.richText.map((part) => part.text).join('').trim()
    return text === '' ? null : text
  }
  if ('error' in value && typeof value.error === 'string') return value.error
  return String(value)
}

function isExcelFormulaValue(value: ExcelCellValue): value is ExcelFormulaValue {
  return (
    value !== null &&
    typeof value === 'object' &&
    ('formula' in value || 'sharedFormula' in value)
  )
}

function normalizeTableRows(
  rows: TableCell[][],
  contract: FileImportScopeContract,
): {
  rows: FileImportParsedRow[]
  mappedColumns: FileImportParseResult['mappedColumns']
  ignoredHeaders: string[]
  issues: FileImportIssue[]
} {
  const issues: FileImportIssue[] = []
  const headerRow = rows.find((row) => row.some((cell) => normalizeCellText(cell) !== null))
  if (!headerRow) {
    return {
      rows: [] as FileImportParsedRow[],
      mappedColumns: [] as FileImportParseResult['mappedColumns'],
      ignoredHeaders: [] as string[],
      issues: [{ level: 'error', code: 'HEADER_ROW_MISSING' }],
    }
  }

  const headerIndex = rows.indexOf(headerRow)
  const headerMap = buildHeaderMap(contract)
  const seenTargets = new Set<string>()
  const mappedColumns: Array<{
    index: number
    sourceHeader: string
    column: FileImportColumn
  }> = []
  const ignoredHeaders: string[] = []

  headerRow.forEach((cell, index) => {
    const sourceHeader = normalizeCellText(cell)
    if (!sourceHeader) return
    const normalized = normalizeHeader(sourceHeader)
    const target = headerMap.get(normalized)
    if (!target) {
      if (isBlockedHeader(normalized)) {
        issues.push({
          level: 'error',
          code: 'SENSITIVE_COLUMN_BLOCKED',
          column: sourceHeader,
        })
      } else {
        ignoredHeaders.push(sourceHeader)
        issues.push({
          level: 'warning',
          code: 'UNKNOWN_COLUMN_IGNORED',
          column: sourceHeader,
        })
      }
      return
    }
    if (seenTargets.has(target.key)) {
      issues.push({
        level: 'error',
        code: 'DUPLICATE_MAPPED_COLUMN',
        column: sourceHeader,
      })
      return
    }
    seenTargets.add(target.key)
    mappedColumns.push({ index, sourceHeader, column: target })
  })

  for (const required of contract.columns.filter((column) => column.required)) {
    if (!seenTargets.has(required.key)) {
      issues.push({ level: 'error', code: 'REQUIRED_COLUMN_MISSING', column: required.key })
    }
  }

  if (issues.some((issue) => issue.level === 'error')) {
    return {
      rows: [] as FileImportParsedRow[],
      mappedColumns: mappedColumns.map((item) => ({
        sourceHeader: item.sourceHeader,
        targetField: item.column.key,
        required: item.column.required,
        type: item.column.type,
      })),
      ignoredHeaders,
      issues,
    }
  }

  const parsedRows: FileImportParsedRow[] = []
  rows.slice(headerIndex + 1).forEach((row, rowOffset) => {
    const rowNumber = headerIndex + rowOffset + 2
    if (row.every((cell) => normalizeCellText(cell) === null)) return
    const payload: Record<string, string | number | boolean | null> = {}

    mappedColumns.forEach((item) => {
      const value = parseCellValue(row[item.index] ?? null, item.column, rowNumber, issues)
      payload[item.column.key] = value
    })

    for (const required of contract.columns.filter((column) => column.required)) {
      if (payload[required.key] === null || payload[required.key] === undefined) {
        issues.push({
          level: 'error',
          code: 'REQUIRED_VALUE_MISSING',
          rowNumber,
          column: required.key,
        })
      }
    }

    const externalId = payload[contract.externalIdField]
    if (typeof externalId !== 'string' || externalId.trim() === '') {
      issues.push({
        level: 'error',
        code: 'EXTERNAL_ID_MISSING',
        rowNumber,
        column: contract.externalIdField,
      })
      return
    }

    parsedRows.push({
      rowNumber,
      entityType: contract.entityType,
      externalId,
      payload,
    })
  })

  if (parsedRows.length === 0) {
    issues.push({ level: 'error', code: 'NO_DATA_ROWS' })
  }
  if (parsedRows.length > FILE_IMPORT_MAX_ROWS) {
    issues.push({
      level: 'error',
      code: 'TOO_MANY_ROWS',
      detail: `${parsedRows.length}/${FILE_IMPORT_MAX_ROWS}`,
    })
  }

  return {
    rows: parsedRows,
    mappedColumns: mappedColumns.map((item) => ({
      sourceHeader: item.sourceHeader,
      targetField: item.column.key,
      required: item.column.required,
      type: item.column.type,
    })),
    ignoredHeaders,
    issues,
  }
}

function parseCellValue(
  rawValue: TableCell,
  column: FileImportColumn,
  rowNumber: number,
  issues: FileImportIssue[],
): string | number | boolean | null {
  const normalizedText = normalizeCellText(rawValue)
  if (normalizedText === null || NULL_LITERALS.has(normalizedText.toLocaleLowerCase('tr-TR'))) {
    if (
      typeof rawValue === 'string' &&
      NULL_LITERALS.has(rawValue.trim().toLocaleLowerCase('tr-TR'))
    ) {
      issues.push({
        level: 'warning',
        code: 'NULL_LITERAL_NORMALIZED',
        rowNumber,
        column: column.key,
      })
    }
    return null
  }

  if (column.type === 'text') return normalizedText
  if (column.type === 'email') {
    const email = normalizedText.toLocaleLowerCase('tr-TR')
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      issues.push({ level: 'error', code: 'INVALID_EMAIL', rowNumber, column: column.key })
    }
    return email
  }
  if (column.type === 'boolean') {
    const value = normalizedText.toLocaleLowerCase('tr-TR')
    if (COMMON_BOOLEAN_TRUE.has(value)) return true
    if (COMMON_BOOLEAN_FALSE.has(value)) return false
    issues.push({ level: 'error', code: 'INVALID_BOOLEAN', rowNumber, column: column.key })
    return null
  }
  if (column.type === 'integer') {
    const numberValue = typeof rawValue === 'number' ? rawValue : Number(normalizedText)
    if (!Number.isInteger(numberValue)) {
      issues.push({ level: 'error', code: 'INVALID_INTEGER', rowNumber, column: column.key })
      return null
    }
    return numberValue
  }
  if (column.type === 'date') {
    const date = normalizeDateValue(rawValue)
    if (!date) {
      issues.push({ level: 'error', code: 'INVALID_DATE', rowNumber, column: column.key })
      return null
    }
    return date
  }
  return normalizedText
}

function buildHeaderMap(contract: FileImportScopeContract): Map<string, FileImportColumn> {
  const map = new Map<string, FileImportColumn>()
  for (const col of contract.columns) {
    map.set(normalizeHeader(col.key), col)
    for (const alias of col.aliases ?? []) {
      map.set(normalizeHeader(alias), col)
    }
  }
  return map
}

function normalizeHeader(value: string): string {
  return value.trim().toLocaleLowerCase('tr-TR').replace(/\s+/g, '_')
}

function normalizeCellText(value: TableCell): string | null {
  if (value === null || value === undefined) return null
  if (value instanceof Date) return formatDateOnly(value)
  const text = String(value).trim()
  return text === '' ? null : text
}

function normalizeDateValue(value: TableCell): string | null {
  if (value instanceof Date && !Number.isNaN(value.getTime())) return formatDateOnly(value)
  const text = normalizeCellText(value)
  if (!text) return null
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) return isValidDateOnly(text) ? text : null
  if (/^\d{4}-\d{2}-\d{2}T/.test(text) && /(?:Z|[+-]\d{2}:\d{2})$/.test(text)) {
    const date = new Date(text)
    return Number.isNaN(date.getTime()) ? null : formatDateOnly(date)
  }
  return null
}

function isValidDateOnly(value: string): boolean {
  const date = new Date(`${value}T00:00:00.000Z`)
  return !Number.isNaN(date.getTime()) && value === date.toISOString().slice(0, 10)
}

function formatDateOnly(date: Date): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: FILE_IMPORT_TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date)
  const year = parts.find((part) => part.type === 'year')?.value
  const month = parts.find((part) => part.type === 'month')?.value
  const day = parts.find((part) => part.type === 'day')?.value
  return `${year}-${month}-${day}`
}

function detectDelimiter(text: string): ',' | ';' | '\t' {
  const sampleLines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 8)
  const candidates: Array<',' | ';' | '\t'> = [',', ';', '\t']
  const scored = candidates.map((delimiter) => {
    const counts = sampleLines.map((line) => countDelimiterOutsideQuotes(line, delimiter))
    const total = counts.reduce((sum, count) => sum + count, 0)
    const variance = counts.reduce((sum, count) => sum + Math.abs(count - counts[0]!), 0)
    return { delimiter, total, variance }
  })
  return scored.sort(
    (left, right) => right.total - left.total || left.variance - right.variance,
  )[0]!.delimiter
}

function countDelimiterOutsideQuotes(line: string, delimiter: ',' | ';' | '\t'): number {
  let inQuotes = false
  let count = 0
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index]
    if (char === '"') {
      if (inQuotes && line[index + 1] === '"') {
        index += 1
      } else {
        inQuotes = !inQuotes
      }
    } else if (!inQuotes && char === delimiter) {
      count += 1
    }
  }
  return count
}

function validateFileName(fileName: string, scope: FileImportScopeId) {
  const match = /^puls_([a-z_]+)_v1_(\d{8})\.(csv|xlsx)$/i.exec(fileName.trim())
  const issues: FileImportIssue[] = []
  if (!match) {
    issues.push({ level: 'error', code: 'INVALID_FILE_NAME', detail: fileName })
    return { businessDate: null, issues }
  }
  const [, fileScope, businessDate] = match
  if (fileScope !== scope) {
    issues.push({ level: 'error', code: 'FILE_SCOPE_MISMATCH', detail: fileScope })
  }
  if (!isValidBusinessDate(businessDate!)) {
    issues.push({ level: 'error', code: 'INVALID_FILE_DATE', detail: businessDate })
  }
  return { businessDate: businessDate!, issues }
}

function isValidBusinessDate(value: string): boolean {
  const formatted = `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`
  return isValidDateOnly(formatted)
}

function formatBusinessDate(date: Date): string {
  return formatDateOnly(date).replaceAll('-', '')
}

function fileExtension(fileName: string): 'csv' | 'xlsx' | null {
  const extension = fileName.split('.').pop()?.toLocaleLowerCase('tr-TR')
  return extension === 'csv' || extension === 'xlsx' ? extension : null
}

function isBlockedHeader(normalizedHeader: string): boolean {
  return BLOCKED_HEADER_PATTERNS.some((pattern) => normalizedHeader.includes(pattern))
}

function escapeCsvValue(value: string): string {
  return /[",\n\r]/.test(value) ? `"${value.replaceAll('"', '""')}"` : value
}

function stripBom(value: string): string {
  return value.charCodeAt(0) === 0xfeff ? value.slice(1) : value
}

async function sha256File(file: File): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', await file.arrayBuffer())
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('')
}
