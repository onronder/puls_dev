import { describe, expect, it, vi } from 'vitest'

import { fromSupabaseError } from '#/lib/data/errors'
import { mapLeaveTypeMutationError } from '#/lib/data/setup/leave-types'

vi.mock('#/lib/data/client', () => ({
  pulsWorkflow: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

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
