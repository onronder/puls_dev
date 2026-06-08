import { describe, expect, it } from 'vitest'
import * as XLSX from 'xlsx'

import {
  buildFileImportCsvTemplate,
  buildFileImportExpectedFileName,
  inferFileImportScopeFromFileName,
  parseFileImport,
  parseFileImportPackage,
} from '#/lib/data/setup/file-import-contract'

function csvFile(name: string, content: string): File {
  return new File([content], name, { type: 'text/csv' })
}

function xlsxFile(name: string, sheet: XLSX.WorkSheet): File {
  const workbook = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(workbook, sheet, 'Import')
  const data = XLSX.write(workbook, { bookType: 'xlsx', type: 'array' }) as ArrayBuffer
  return new File([data], name, {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  })
}

describe('file import contract', () => {
  it('builds a dated CSV template with canonical headers', () => {
    expect(
      buildFileImportExpectedFileName('employees', new Date('2026-06-08T09:00:00+03:00')),
    ).toBe('puls_employees_v1_20260608.csv')
    expect(buildFileImportCsvTemplate('employees')).toContain(
      'employee_code,full_name,email,job_title',
    )
  })

  it('parses semicolon CSV with Turkish characters and null literals', async () => {
    const result = await parseFileImport(
      csvFile(
        'puls_employees_v1_20260608.csv',
        [
          'çalışan_kodu;ad_soyad;email;ise_giris_tarihi;department_code',
          'E-001;Ayşe Öz;AYSE@example.com;2026-06-08;NULL',
        ].join('\n'),
      ),
      'employees',
    )

    expect(result.ok).toBe(true)
    expect(result.delimiter).toBe(';')
    expect(result.rowCount).toBe(1)
    expect(result.rows[0]).toMatchObject({
      rowNumber: 2,
      entityType: 'employee',
      externalId: 'E-001',
      payload: {
        employee_code: 'E-001',
        full_name: 'Ayşe Öz',
        email: 'ayse@example.com',
        hire_date: '2026-06-08',
        department_code: null,
      },
    })
    expect(result.issues.map((issue) => issue.code)).toContain('NULL_LITERAL_NORMALIZED')
  })

  it('rejects invalid names before staging rows', async () => {
    const result = await parseFileImport(
      csvFile('Calisanlar06082026.csv', 'employee_code,full_name\nE-001,Ayşe Öz\n'),
      'employees',
    )

    expect(result.ok).toBe(false)
    expect(result.rowCount).toBe(0)
    expect(result.issues).toContainEqual(
      expect.objectContaining({ code: 'INVALID_FILE_NAME', level: 'error' }),
    )
  })

  it('blocks sensitive columns by header name', async () => {
    const result = await parseFileImport(
      csvFile(
        'puls_employees_v1_20260608.csv',
        'employee_code,full_name,maas\nE-001,Ayşe Öz,50000\n',
      ),
      'employees',
    )

    expect(result.ok).toBe(false)
    expect(result.issues).toContainEqual(
      expect.objectContaining({ code: 'SENSITIVE_COLUMN_BLOCKED', column: 'maas' }),
    )
  })

  it('rejects ambiguous slash-formatted dates', async () => {
    const result = await parseFileImport(
      csvFile(
        'puls_employees_v1_20260608.csv',
        'employee_code,full_name,hire_date\nE-001,Ayşe Öz,06/08/2026\n',
      ),
      'employees',
    )

    expect(result.ok).toBe(false)
    expect(result.issues).toContainEqual(
      expect.objectContaining({ code: 'INVALID_DATE', column: 'hire_date' }),
    )
  })

  it('rejects Excel formula cells when cached value is unavailable', async () => {
    const sheet = XLSX.utils.aoa_to_sheet([
      ['employee_code', 'full_name'],
      ['E-001', null],
    ])
    sheet.B2 = { t: 'n', f: '1+1' }

    const result = await parseFileImport(
      xlsxFile('puls_employees_v1_20260608.xlsx', sheet),
      'employees',
    )

    expect(result.ok).toBe(false)
    expect(result.issues).toContainEqual(
      expect.objectContaining({ code: 'XLSX_FORMULA_VALUE_MISSING', rowNumber: 2 }),
    )
  })

  it('infers scope from the PULS filename contract', () => {
    expect(inferFileImportScopeFromFileName('puls_departments_v1_20260608.csv')).toBe(
      'departments',
    )
    expect(inferFileImportScopeFromFileName('Calisanlar06082026.csv')).toBeNull()
  })

  it('parses a multi-file HR import package in dependency order', async () => {
    const packageResult = await parseFileImportPackage(
      [
        csvFile('puls_employees_v1_20260608.csv', 'employee_code,full_name\nE-001,Ayşe Öz\n'),
        csvFile('puls_departments_v1_20260608.csv', 'code,name\nD-001,İnsan Kaynakları\n'),
        csvFile('puls_legal_entities_v1_20260608.csv', 'code,name\nLE-001,PULS Demo\n'),
      ],
      ['employees', 'departments', 'legal_entities'],
      'package-1',
    )

    expect(packageResult.ok).toBe(true)
    expect(packageResult.packageId).toBe('package-1')
    expect(packageResult.fileCount).toBe(3)
    expect(packageResult.rowCount).toBe(3)
    expect(packageResult.files.map((item) => item.scope)).toEqual([
      'legal_entities',
      'departments',
      'employees',
    ])
  })

  it('blocks duplicate scopes inside the same package', async () => {
    const packageResult = await parseFileImportPackage(
      [
        csvFile('puls_departments_v1_20260608.csv', 'code,name\nD-001,İnsan Kaynakları\n'),
        csvFile('puls_departments_v1_20260609.csv', 'code,name\nD-002,Finans\n'),
      ],
      ['departments'],
      'package-1',
    )

    expect(packageResult.ok).toBe(false)
    expect(packageResult.issues).toContainEqual(
      expect.objectContaining({ code: 'DUPLICATE_SCOPE_IN_PACKAGE', level: 'error' }),
    )
  })
})
