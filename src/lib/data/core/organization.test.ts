import { describe, expect, it } from 'vitest'

import { DataAdapterError } from '#/lib/data/errors'
import { computeOpenHeadcount } from '#/lib/data/core/lookups'
import {
  fetchDemoDepartmentsOverview,
  fetchDemoPositionsOverview,
} from '#/lib/demo/puls-demo-data'
import { isOrgEntityEditable } from '#/lib/data/setup/org-entity-source'
import {
  applyOrgEntityLifecycleFilter,
  mapDepartmentMutationError,
  mapDepartmentLifecycleError,
  mapPositionLifecycleError,
  mapPositionMutationError,
} from '#/lib/data/core/organization'

describe('positions open headcount', () => {
  it('computes open positions from norm headcount minus filled count', () => {
    expect(computeOpenHeadcount(5, 3)).toBe(2)
    expect(computeOpenHeadcount(3, 5)).toBe(0)
  })
})

describe('isOrgEntityEditable', () => {
  it('allows puls source only', () => {
    expect(isOrgEntityEditable('puls')).toBe(true)
    expect(isOrgEntityEditable('erp')).toBe(false)
    expect(isOrgEntityEditable('demo')).toBe(false)
    expect(isOrgEntityEditable('unknown')).toBe(false)
  })
})

describe('organization overview row shape', () => {
  it('includes code, isActive, source, and isEditable on department rows', async () => {
    const overview = await fetchDemoDepartmentsOverview()

    for (const department of overview.departments) {
      expect(department).toMatchObject({
        code: expect.any(String),
        isActive: expect.any(Boolean),
        source: expect.stringMatching(/^(puls|erp|demo|unknown)$/),
        isEditable: expect.any(Boolean),
      })
      expect(department.isEditable).toBe(isOrgEntityEditable(department.source))
    }
  })

  it('includes departmentId and normHeadcount on position rows', async () => {
    const overview = await fetchDemoPositionsOverview()

    for (const position of overview.positions) {
      expect(position).toMatchObject({
        code: expect.any(String),
        isActive: expect.any(Boolean),
        source: expect.stringMatching(/^(puls|erp|demo|unknown)$/),
        isEditable: expect.any(Boolean),
        normHeadcount: expect.any(Number),
      })
    }
  })
})

describe('applyOrgEntityLifecycleFilter', () => {
  const rows = [
    { id: 'active-a', isActive: true },
    { id: 'inactive-a', isActive: false },
  ]

  it('filters active, inactive, and all rows', () => {
    expect(applyOrgEntityLifecycleFilter(rows, 'active').map((row) => row.id)).toEqual(['active-a'])
    expect(applyOrgEntityLifecycleFilter(rows, 'inactive').map((row) => row.id)).toEqual(['inactive-a'])
    expect(applyOrgEntityLifecycleFilter(rows, 'all').map((row) => row.id)).toEqual([
      'active-a',
      'inactive-a',
    ])
  })
})

describe('mapDepartmentMutationError', () => {
  it('maps source read-only puls code', () => {
    const error = new DataAdapterError({
      code: 'P0001',
      message: 'PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY: imported departments cannot be edited locally.',
      source: 'supabase',
      operation: 'updateDepartment',
      schema: 'puls_core',
      table: 'departments',
    })

    expect(mapDepartmentMutationError(error)).toEqual({
      fieldErrors: { code: 'orgSetupCrud.validation.sourceReadOnly' },
    })
  })

  it('maps code duplicate 23505', () => {
    const error = new DataAdapterError({
      code: '23505',
      message: 'duplicate key value violates unique constraint "(tenant_id, code)"',
      source: 'supabase',
      operation: 'createDepartment',
      schema: 'puls_core',
      table: 'departments',
    })

    expect(mapDepartmentMutationError(error)).toEqual({
      fieldErrors: { code: 'orgSetupCrud.validation.duplicateCode' },
    })
  })
})

describe('mapPositionMutationError', () => {
  it('maps invalid department field', () => {
    const error = new DataAdapterError({
      code: 'P0001',
      message: 'PULS_ORG_POSITION_DEPARTMENT_INVALID: department_id is invalid for this tenant.',
      source: 'supabase',
      operation: 'createPosition',
      schema: 'puls_core',
      table: 'positions',
    })

    expect(mapPositionMutationError(error)).toEqual({
      fieldErrors: { departmentId: 'orgSetupCrud.validation.departmentInvalid' },
    })
  })
})

describe('org lifecycle error mapping', () => {
  it('maps department dependency blockers', () => {
    const error = new DataAdapterError({
      code: 'P0001',
      message:
        'PULS_ORG_DEPARTMENT_IN_USE_ACTIVE_EMPLOYEES: department has active employees.',
      source: 'supabase',
      operation: 'deactivateDepartment',
      schema: 'puls_core',
      table: 'departments',
    })

    expect(mapDepartmentLifecycleError(error)).toEqual({
      toastKey: 'orgSetupCrud.lifecycle.errors.departmentActiveEmployees',
    })
  })

  it('maps position restore blockers', () => {
    const error = new DataAdapterError({
      code: 'P0001',
      message:
        'PULS_ORG_POSITION_DEPARTMENT_INACTIVE: department must be active before restore.',
      source: 'supabase',
      operation: 'restorePosition',
      schema: 'puls_core',
      table: 'positions',
    })

    expect(mapPositionLifecycleError(error)).toEqual({
      toastKey: 'orgSetupCrud.lifecycle.errors.positionDepartmentInactive',
    })
  })
})
