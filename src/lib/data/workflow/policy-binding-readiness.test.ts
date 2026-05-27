import { describe, expect, it } from 'vitest'

import {
  buildApprovalPolicyBindingInfo,
  computeApprovalPolicyBindingStatus,
} from '#/lib/data/workflow/policy-binding-readiness'

describe('computeApprovalPolicyBindingStatus', () => {
  it('returns unbound when policy id is missing', () => {
    expect(
      computeApprovalPolicyBindingStatus({
        expectedModule: 'expense',
        policyId: null,
        policyModule: null,
        policyIsActive: null,
        requiredStepCount: 0,
      }),
    ).toBe('unbound')
  })

  it('returns policy_unavailable when policy id is set but metadata is missing', () => {
    expect(
      computeApprovalPolicyBindingStatus({
        expectedModule: 'expense',
        policyId: 'policy-1',
        policyModule: null,
        policyIsActive: null,
        requiredStepCount: 0,
      }),
    ).toBe('policy_unavailable')
  })

  it('returns inactive_policy when readable policy is not active', () => {
    expect(
      computeApprovalPolicyBindingStatus({
        expectedModule: 'expense',
        policyId: 'policy-1',
        policyModule: 'expense',
        policyIsActive: false,
        requiredStepCount: 1,
      }),
    ).toBe('inactive_policy')
  })

  it('returns module_mismatch when policy module differs', () => {
    expect(
      computeApprovalPolicyBindingStatus({
        expectedModule: 'expense',
        policyId: 'policy-1',
        policyModule: 'leave',
        policyIsActive: true,
        requiredStepCount: 1,
      }),
    ).toBe('module_mismatch')
  })

  it('returns missing_required_steps when no required steps exist', () => {
    expect(
      computeApprovalPolicyBindingStatus({
        expectedModule: 'leave',
        policyId: 'policy-1',
        policyModule: 'leave',
        policyIsActive: true,
        requiredStepCount: 0,
      }),
    ).toBe('missing_required_steps')
  })

  it('returns ready for active policy with required steps', () => {
    expect(
      computeApprovalPolicyBindingStatus({
        expectedModule: 'expense',
        policyId: 'policy-1',
        policyModule: 'expense',
        policyIsActive: true,
        requiredStepCount: 2,
      }),
    ).toBe('ready')
  })
})

describe('buildApprovalPolicyBindingInfo', () => {
  it('assembles binding info with computed status', () => {
    expect(
      buildApprovalPolicyBindingInfo({
        expectedModule: 'expense',
        policyId: 'policy-1',
        policyName: 'Masraf onay',
        policyModule: 'expense',
        policyIsActive: true,
        requiredStepCount: 1,
      }),
    ).toEqual({
      policyId: 'policy-1',
      policyName: 'Masraf onay',
      policyModule: 'expense',
      policyIsActive: true,
      requiredStepCount: 1,
      status: 'ready',
    })
  })
})
