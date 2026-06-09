import type { QueryClient } from '@tanstack/react-query'
import { describe, expect, it, vi } from 'vitest'

import { invalidateOrgStructureQueries } from '#/lib/data/query-invalidation'

describe('invalidateOrgStructureQueries', () => {
  it('invalidates org setup, employee, dashboard, and readiness caches', () => {
    const invalidateQueries = vi.fn()
    const queryClient = { invalidateQueries } as unknown as QueryClient

    invalidateOrgStructureQueries(queryClient, 'user-1')

    expect(invalidateQueries).toHaveBeenCalledWith({
      queryKey: ['departments-overview', 'user-1'],
    })
    expect(invalidateQueries).toHaveBeenCalledWith({
      queryKey: ['positions-overview', 'user-1'],
    })
    expect(invalidateQueries).toHaveBeenCalledWith({
      queryKey: ['employee-assignment-readiness', 'user-1'],
    })
    expect(invalidateQueries).toHaveBeenCalledWith({
      queryKey: ['employees-overview-leave', 'user-1'],
    })
    expect(invalidateQueries).toHaveBeenCalledWith({
      queryKey: ['dashboard-overview', 'user-1'],
    })
    expect(invalidateQueries).toHaveBeenCalledWith({
      queryKey: ['setup-readiness-dashboard', 'user-1'],
    })
    expect(invalidateQueries).toHaveBeenCalledTimes(6)
  })
})
