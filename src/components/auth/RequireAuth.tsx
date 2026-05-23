import { Navigate, useRouterState } from '@tanstack/react-router'

import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import { buildRedirectPath } from '#/lib/safe-redirect'

export function RequireAuth({ children }: { children: React.ReactNode }) {
  const { session, isLoading } = useAuth()
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const searchStr = useRouterState({ select: (s) => s.location.searchStr })

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[var(--color-bg-base)]">
        <Skeleton className="h-8 w-48 rounded-lg" />
      </div>
    )
  }

  if (!session) {
    return (
      <Navigate
        to="/login"
        search={{ redirect: buildRedirectPath(pathname, searchStr) }}
        replace
      />
    )
  }

  return children
}
