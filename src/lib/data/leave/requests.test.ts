import { describe, expect, it } from 'vitest'

import { DataAdapterError, isDataAdapterError } from '#/lib/data/errors'
import { parseCreateLeaveRequestResult } from '#/lib/data/leave/requests'

const validPayload = {
  leave_request_id: 'lr-1',
  approval_request_id: 'ar-1',
  business_days: 2,
  status: 'pending',
  approver_employee_id: 'emp-1',
  approver_name: 'Approver One',
}

describe('parseCreateLeaveRequestResult', () => {
  it('parses a valid full object with numeric business_days', () => {
    expect(parseCreateLeaveRequestResult(validPayload)).toEqual({
      leaveRequestId: 'lr-1',
      approvalRequestId: 'ar-1',
      businessDays: 2,
      status: 'pending',
      approverEmployeeId: 'emp-1',
      approverName: 'Approver One',
    })
  })

  it('coerces string numeric business_days via Number()', () => {
    expect(
      parseCreateLeaveRequestResult({
        ...validPayload,
        business_days: '2.5',
      }),
    ).toEqual({
      leaveRequestId: 'lr-1',
      approvalRequestId: 'ar-1',
      businessDays: 2.5,
      status: 'pending',
      approverEmployeeId: 'emp-1',
      approverName: 'Approver One',
    })
  })

  it('accepts null approver_name', () => {
    expect(
      parseCreateLeaveRequestResult({
        ...validPayload,
        approver_name: null,
      }),
    ).toMatchObject({ approverName: null })
  })

  it('rejects non-object data', () => {
    expect(() => parseCreateLeaveRequestResult(null)).toThrow(DataAdapterError)
    expect(() => parseCreateLeaveRequestResult('bad')).toThrow(DataAdapterError)
  })

  it('rejects missing approval_request_id', () => {
    try {
      parseCreateLeaveRequestResult({
        ...validPayload,
        approval_request_id: '',
      })
      expect.unreachable('expected throw')
    } catch (error) {
      expect(isDataAdapterError(error)).toBe(true)
      if (isDataAdapterError(error)) {
        expect(error.code).toBe('invalid_rpc_result')
        expect(error.operation).toBe('createLeaveRequest')
        expect(error.i18nKey).toBe('leave.error.submitFailed')
      }
    }
  })

  it('rejects missing business_days', () => {
    expect(() =>
      parseCreateLeaveRequestResult({
        ...validPayload,
        business_days: undefined,
      }),
    ).toThrow(DataAdapterError)
  })

  it('rejects non-finite business_days', () => {
    expect(() =>
      parseCreateLeaveRequestResult({
        ...validPayload,
        business_days: 'not-a-number',
      }),
    ).toThrow(DataAdapterError)
  })
})
