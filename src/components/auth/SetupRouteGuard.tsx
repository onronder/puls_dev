import { useNavigate } from '@tanstack/react-router'
import { useEffect, type ReactNode } from 'react'

import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import { canShowSetupHub } from '#/lib/setup-access'

export function SetupRouteGuard({ children }: { children: ReactNode }) {
  const { personaRole, activePersona, isLoading } = useAuth()
  const navigate = useNavigate()
  const allowed = canShowSetupHub(personaRole, activePersona)
  const isPersonaPending = !isLoading && personaRole === null

  useEffect(() => {
    if (!isLoading && !isPersonaPending && !allowed) {
      void navigate({ to: '/ayarlar', replace: true })
    }
  }, [isLoading, isPersonaPending, allowed, navigate])

  if (isLoading || isPersonaPending) {
    return (
      <div className="mx-auto max-w-5xl p-4 md:p-8">
        <Skeleton className="h-96 w-full rounded-xl" />
      </div>
    )
  }

  if (!allowed) {
    return null
  }

  return children
}
