import { afterEach, describe, expect, it, vi } from 'vitest'

import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import { DataAdapterError } from '#/lib/data/errors'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)

describe('resolveAdapterData', () => {
  afterEach(() => {
    demoEnabled.mockReset()
  })

  it('returns real data when non-empty', async () => {
    demoEnabled.mockReturnValue(false)
    const data = await resolveAdapterData({
      operation: 'test',
      fetchReal: async () => ({ count: 2 }),
      fetchDemo: async () => ({ count: 99 }),
      isEmpty: (value) => value.count === 0,
    })

    expect(data).toEqual({ count: 2 })
  })

  it('returns empty shape when real is empty and demo mode is off', async () => {
    demoEnabled.mockReturnValue(false)
    const data = await resolveAdapterData({
      operation: 'test',
      fetchReal: async () => ({ count: 0 }),
      fetchDemo: async () => ({ count: 99 }),
      isEmpty: (value) => value.count === 0,
    })

    expect(data).toEqual({ count: 0 })
  })

  it('returns demo fallback when real is empty and demo mode is on', async () => {
    demoEnabled.mockReturnValue(true)
    const data = await resolveAdapterData({
      operation: 'test',
      fetchReal: async () => ({ count: 0 }),
      fetchDemo: async () => ({ count: 99 }),
      isEmpty: (value) => value.count === 0,
    })

    expect(data).toEqual({ count: 99 })
  })

  it('throws normalized error when real fails and demo mode is off', async () => {
    demoEnabled.mockReturnValue(false)

    await expect(
      resolveAdapterData({
        operation: 'test',
        fetchReal: async () => {
          throw new DataAdapterError({
            code: '42501',
            message: 'denied',
            source: 'supabase',
            operation: 'test',
          })
        },
        fetchDemo: async () => ({ count: 99 }),
      }),
    ).rejects.toBeInstanceOf(DataAdapterError)
  })

  it('returns demo fallback when real fails and demo mode is on', async () => {
    demoEnabled.mockReturnValue(true)
    const data = await resolveAdapterData({
      operation: 'test',
      fetchReal: async () => {
        throw new Error('db down')
      },
      fetchDemo: async () => ({ count: 99 }),
    })

    expect(data).toEqual({ count: 99 })
  })

  it('resolveAdapterDataWithMeta exposes source metadata', async () => {
    demoEnabled.mockReturnValue(false)
    const result = await resolveAdapterDataWithMeta({
      operation: 'test',
      fetchReal: async () => [1],
      fetchDemo: async () => [9],
      isEmpty: (value) => value.length === 0,
    })

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data).toEqual([1])
  })
})
