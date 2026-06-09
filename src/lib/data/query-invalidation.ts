import type { QueryClient } from '@tanstack/react-query'

export function invalidateOrgStructureQueries(queryClient: QueryClient, userId: string): void {
  const queryKeys = [
    ['departments-overview', userId],
    ['positions-overview', userId],
    ['employee-assignment-readiness', userId],
    ['employees-overview-leave', userId],
    ['dashboard-overview', userId],
    ['setup-readiness-dashboard', userId],
  ] as const

  for (const queryKey of queryKeys) {
    void queryClient.invalidateQueries({ queryKey: [...queryKey] })
  }
}
