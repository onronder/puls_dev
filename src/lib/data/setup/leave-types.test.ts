import { describe, expect, it, vi } from 'vitest'

import { fromSupabaseError } from '#/lib/data/errors'
import {
  applyLeaveTypeLifecycleFilter,
  isDeactivateLeaveTypeReasonTooLong,
  mapLeaveTypeLifecycleError,
  mapLeaveTypeLifecycleEventRow,
  mapLeaveTypeMutationError,
  normalizeDeactivateLeaveTypeReason,
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

describe('normalizeDeactivateLeaveTypeReason', () => {
  it('trims and returns null for blank input', () => {
    expect(normalizeDeactivateLeaveTypeReason('  hello  ')).toBe('hello')
    expect(normalizeDeactivateLeaveTypeReason('   ')).toBeNull()
    expect(normalizeDeactivateLeaveTypeReason(null)).toBeNull()
  })
})

describe('isDeactivateLeaveTypeReasonTooLong', () => {
  it('returns false for valid length and true above 500 chars', () => {
    expect(isDeactivateLeaveTypeReasonTooLong('short note')).toBe(false)
    expect(isDeactivateLeaveTypeReasonTooLong('x'.repeat(501))).toBe(true)
    expect(isDeactivateLeaveTypeReasonTooLong('   ')).toBe(false)
  })
})

describe('parseLeaveTypeLifecycleRpcResult', () => {
  it('parses deactivated result with required eventId', () => {
    expect(
      parseLeaveTypeLifecycleRpcResult({
        status: 'deactivated',
        leave_type_id: 'lt-1',
        has_history: true,
        event_id: 'evt-1',
      }),
    ).toEqual({
      status: 'deactivated',
      leaveTypeId: 'lt-1',
      hasHistory: true,
      eventId: 'evt-1',
    })
  })

  it('parses restored and idempotent statuses', () => {
    expect(
      parseLeaveTypeLifecycleRpcResult({
        status: 'restored',
        leave_type_id: 'lt-2',
        event_id: 'evt-2',
      }),
    ).toEqual({ status: 'restored', leaveTypeId: 'lt-2', eventId: 'evt-2' })
    expect(
      parseLeaveTypeLifecycleRpcResult({ status: 'already_inactive', leave_type_id: 'lt-3' }),
    ).toEqual({ status: 'already_inactive', leaveTypeId: 'lt-3' })
    expect(
      parseLeaveTypeLifecycleRpcResult({ status: 'already_active', leave_type_id: 'lt-4' }),
    ).toEqual({ status: 'already_active', leaveTypeId: 'lt-4' })
  })

  it('throws when state-change result omits event_id', () => {
    expect(() =>
      parseLeaveTypeLifecycleRpcResult({
        status: 'deactivated',
        leave_type_id: 'lt-1',
        has_history: false,
      }),
    ).toThrow(/Missing event_id/)

    expect(() =>
      parseLeaveTypeLifecycleRpcResult({
        status: 'restored',
        leave_type_id: 'lt-1',
      }),
    ).toThrow(/Missing event_id/)
  })
})

describe('mapLeaveTypeLifecycleEventRow', () => {
  it('maps snake_case lifecycle event rows', () => {
    expect(
      mapLeaveTypeLifecycleEventRow({
        id: 'evt-1',
        leave_type_id: 'lt-1',
        action: 'deactivated',
        reason: 'Policy review',
        actor_role: 'authenticated',
        occurred_at: '2026-05-25T12:00:00.000Z',
      }),
    ).toEqual({
      id: 'evt-1',
      leaveTypeId: 'lt-1',
      action: 'deactivated',
      reason: 'Policy review',
      actorRole: 'authenticated',
      occurredAt: '2026-05-25T12:00:00.000Z',
    })
  })

  it('maps blank reason to null', () => {
    expect(
      mapLeaveTypeLifecycleEventRow({
        id: 'evt-2',
        leave_type_id: 'lt-1',
        action: 'restored',
        reason: null,
        actor_role: null,
        occurred_at: '2026-05-25T13:00:00.000Z',
      }),
    ).toEqual({
      id: 'evt-2',
      leaveTypeId: 'lt-1',
      action: 'restored',
      reason: null,
      actorRole: null,
      occurredAt: '2026-05-25T13:00:00.000Z',
    })
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

  it('maps reason-too-long to lifecycle audit toast key', () => {
    const error = fromSupabaseError(
      {
        code: 'P0001',
        message:
          'PULS_LEAVE_TYPE_LIFECYCLE_REASON_TOO_LONG: reason must be at most 500 characters.',
        details: '',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'deactivateLeaveType',
      'puls_workflow',
      'leave_types',
    )

    expect(mapLeaveTypeLifecycleError(error)).toEqual({
      toastKey: 'leaveTypeSetup.lifecycleAudit.reasonTooLong',
    })
  })

  it('falls back to generic lifecycle error', () => {
    expect(mapLeaveTypeLifecycleError(new Error('network'))).toEqual({
      toastKey: 'leaveTypeSetup.lifecycle.errors.generic',
    })
  })
})

describe('fetchLeaveTypeLifecycleEvents', () => {
  it('returns empty array when tenant context is missing', async () => {
    const { resolveTenantContext } = await import('#/lib/data/client')
    vi.mocked(resolveTenantContext).mockResolvedValueOnce({
      tenantId: null,
      tenantName: null,
      employeeId: null,
      employeeName: null,
      personaRole: 'employee',
    })

    const { fetchLeaveTypeLifecycleEvents } = await import('#/lib/data/setup/leave-types')

    await expect(fetchLeaveTypeLifecycleEvents('user-1', 'lt-1')).resolves.toEqual([])
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
