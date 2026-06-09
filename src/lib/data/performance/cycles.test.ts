import { describe, expect, it } from 'vitest'

import { DataAdapterError } from '#/lib/data/errors'
import {
  canTransitionPerformanceCycleStatus,
  normalizePerformanceCycleName,
  parsePerformanceCycleMutationResult,
  parsePerformanceCycleRow,
  validatePerformanceCycleInput,
} from '#/lib/data/performance/cycles'

const validInput = {
  name: '2026 Q2',
  starts_at: '2026-04-01',
  ends_at: '2026-06-30',
  status: 'draft' as const,
}

describe('normalizePerformanceCycleName', () => {
  it('trims whitespace', () => {
    expect(normalizePerformanceCycleName('  Annual  ')).toBe('Annual')
  })
})

describe('validatePerformanceCycleInput', () => {
  it('accepts valid input', () => {
    expect(validatePerformanceCycleInput(validInput)).toEqual({
      ok: true,
      value: validInput,
    })
  })

  it('rejects blank name', () => {
    const result = validatePerformanceCycleInput({ ...validInput, name: '   ' })
    expect(result.ok).toBe(false)
    if (!result.ok) {
      expect(result.errors.name).toBe('name_required')
    }
  })

  it('rejects missing dates', () => {
    const result = validatePerformanceCycleInput({ ...validInput, starts_at: '', ends_at: '' })
    expect(result.ok).toBe(false)
    if (!result.ok) {
      expect(result.errors.starts_at).toBe('starts_at_required')
      expect(result.errors.ends_at).toBe('ends_at_required')
    }
  })

  it('rejects end date on or before start date', () => {
    const result = validatePerformanceCycleInput({
      ...validInput,
      starts_at: '2026-06-30',
      ends_at: '2026-04-01',
    })
    expect(result.ok).toBe(false)
    if (!result.ok) {
      expect(result.errors.ends_at).toBe('ends_at_before_start')
    }
  })

  it('rejects invalid status', () => {
    const result = validatePerformanceCycleInput({
      ...validInput,
      status: 'published' as 'draft',
    })
    expect(result.ok).toBe(false)
    if (!result.ok) {
      expect(result.errors.status).toBe('status_invalid')
    }
  })
})

describe('parsePerformanceCycleRow', () => {
  it('parses valid row', () => {
    expect(
      parsePerformanceCycleRow({
        id: 'cycle-1',
        name: '2026 Q2',
        status: 'draft',
        starts_at: '2026-04-01',
        ends_at: '2026-06-30',
        created_at: '2026-03-01T00:00:00.000Z',
      }),
    ).toEqual({
      id: 'cycle-1',
      name: '2026 Q2',
      status: 'draft',
      starts_at: '2026-04-01',
      ends_at: '2026-06-30',
      created_at: '2026-03-01T00:00:00.000Z',
    })
  })

  it('rejects invalid status', () => {
    expect(() =>
      parsePerformanceCycleRow({
        id: 'cycle-1',
        name: '2026 Q2',
        status: 'published',
        starts_at: '2026-04-01',
        ends_at: '2026-06-30',
        created_at: '2026-03-01T00:00:00.000Z',
      }),
    ).toThrow(DataAdapterError)
  })
})

describe('parsePerformanceCycleMutationResult', () => {
  it('parses mutation payload', () => {
    expect(
      parsePerformanceCycleMutationResult({
        id: 'cycle-2',
        name: '2026 Q3',
        status: 'active',
        starts_at: '2026-07-01',
        ends_at: '2026-09-30',
        created_at: '2026-06-15T00:00:00.000Z',
      }),
    ).toMatchObject({ id: 'cycle-2', status: 'active' })
  })

  it('rejects non-object mutation payload', () => {
    expect(() => parsePerformanceCycleMutationResult(null)).toThrow(DataAdapterError)
  })
})

describe('canTransitionPerformanceCycleStatus', () => {
  it('allows stable no-op status updates', () => {
    expect(canTransitionPerformanceCycleStatus('draft', 'draft')).toBe(true)
    expect(canTransitionPerformanceCycleStatus('active', 'active')).toBe(true)
    expect(canTransitionPerformanceCycleStatus('closed', 'closed')).toBe(true)
  })

  it('allows only draft to active and active to closed lifecycle moves', () => {
    expect(canTransitionPerformanceCycleStatus('draft', 'active')).toBe(true)
    expect(canTransitionPerformanceCycleStatus('active', 'closed')).toBe(true)
    expect(canTransitionPerformanceCycleStatus('draft', 'closed')).toBe(false)
    expect(canTransitionPerformanceCycleStatus('active', 'draft')).toBe(false)
    expect(canTransitionPerformanceCycleStatus('closed', 'active')).toBe(false)
  })
})
