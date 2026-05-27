import { describe, expect, it, vi } from 'vitest'

import { fromSupabaseError } from '#/lib/data/errors'
import {
  applyLeaveTypeLifecycleFilter,
  mapLeaveTypeLifecycleError,
  mapLeaveTypeMutationError,
  parseLeaveTypeLifecycleRpcResult,
} from '#/lib/data/setup/leave-types'

vi.mock('#/lib/data/client', () => ({
  pulsWorkflow: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

const sampleLeaveTypes = [
  { id: '1', isActive: true, name: 'Annual' },
  { id: '2', isActive: false, name: 'Legacy' },
  { id: '3', isActive: true, name: 'Sick' },
]

describe('applyLeaveTypeLifecycleFilter', () => {
  it('filters active leave types', () => {
    expect(applyLeaveTypeLifecycleFilter(sampleLeaveTypes, 'active')).toEqual([
      sampleLeaveTypes[0],
      sampleLeaveTypes[2],
    ])
  })

  it('filters inactive leave types', () => {
    expect(applyLeaveTypeLifecycleFilter(sampleLeaveTypes, 'inactive')).toEqual([
      sampleLeaveTypes[1],
    ])
  })

  it('returns all leave types for all filter', () => {
    expect(applyLeaveTypeLifecycleFilter(sampleLeaveTypes, 'all')).toEqual(sampleLeaveTypes)
  })
})

describe('parseLeaveTypeLifecycleRpcResult', () => {
  it('parses deactivated result', () => {
    expect(
      parseLeaveTypeLifecycleRpcResult({
        status: 'deactivated',
        leave_type_id: 'lt-1',
        has_history: true,
      }),
    ).toEqual({
      status: 'deactivated',
      leaveTypeId: 'lt-1',
      hasHistory: true,
    })
  })

  it('parses restored and idempotent statuses', () => {
    expect(
      parseLeaveTypeLifecycleRpcResult({ status: 'restored', leave_type_id: 'lt-2' }),
    ).toEqual({ status: 'restored', leaveTypeId: 'lt-2' })
    expect(
      parseLeaveTypeLifecycleRpcResult({ status: 'already_inactive', leave_type_id: 'lt-3' }),
    ).toEqual({ status: 'already_inactive', leaveTypeId: 'lt-3' })
    expect(
      parseLeaveTypeLifecycleRpcResult({ status: 'already_active', leave_type_id: 'lt-4' }),
    ).toEqual({ status: 'already_active', leaveTypeId: 'lt-4' })
  })
})

describe('mapLeaveTypeLifecycleError', () => {
  it('maps active request guard to toast key', () => {
    const error = fromSupabaseError(
      {
        code: 'P0001',
        message: 'PULS_LEAVE_TYPE_IN_USE_ACTIVE_REQUESTS: leave type has open leave requests.',
        details: '',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'deactivateLeaveType',
      'puls_workflow',
      'leave_types',
    )

    expect(mapLeaveTypeLifecycleError(error)).toEqual({
      toastKey: 'leaveTypeSetup.lifecycle.errors.activeRequests',
    })
  })

  it('falls back to generic lifecycle error', () => {
    expect(mapLeaveTypeLifecycleError(new Error('network'))).toEqual({
      toastKey: 'leaveTypeSetup.lifecycle.errors.generic',
    })
  })
})

describe('mapLeaveTypeMutationError', () => {
  it('maps PULS guardrail codes to field i18n keys', () => {
    const error = fromSupabaseError(
      {
        code: 'P0001',
        message: 'PULS_LEAVE_TYPE_CODE_INVALID: code must be lowercase slug.',
        details: '',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'createLeaveType',
      'puls_workflow',
      'leave_types',
    )

    expect(mapLeaveTypeMutationError(error)).toEqual({
      fieldErrors: {
        code: 'leaveTypeSetup.validation.codeInvalid',
      },
    })
  })

  it('maps policy module mismatch to approvalPolicyId field', () => {
    const error = fromSupabaseError(
      {
        code: 'P0001',
        message: 'PULS_LEAVE_TYPE_POLICY_MODULE_INVALID: approval policy module must be leave.',
        details: '',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'updateLeaveType',
      'puls_workflow',
      'leave_types',
    )

    expect(mapLeaveTypeMutationError(error)).toEqual({
      fieldErrors: {
        approvalPolicyId: 'leaveTypeSetup.validation.policyModuleInvalid',
      },
    })
  })

  it('maps code duplicate 23505 when tenant_id+code appears in message', () => {
    const error = fromSupabaseError(
      {
        code: '23505',
        message: 'duplicate key value violates unique constraint "leave_types_tenant_id_code_key"',
        details: 'Key (tenant_id, code)=(...) already exists.',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'createLeaveType',
      'puls_workflow',
      'leave_types',
    )

    expect(mapLeaveTypeMutationError(error)).toEqual({
      fieldErrors: {
        code: 'leaveTypeSetup.validation.duplicateCode',
      },
    })
  })
})
