import { Outlet, createFileRoute } from '@tanstack/react-router'

import { RequireAuth } from '#/components/auth/RequireAuth'
import { AppHeader } from '#/components/layout/AppHeader'
import { BottomTabNav } from '#/components/layout/BottomTabNav'
import { FloatingAIButton } from '#/components/layout/FloatingAIButton'
import { Sidebar } from '#/components/layout/Sidebar'

export const Route = createFileRoute('/_app')({
  component: AppLayout,
})

function AppLayout() {
  return (
    <RequireAuth>
      <div className="flex min-h-screen flex-col bg-[var(--color-bg-base)]">
        <AppHeader />
        <div className="flex flex-1">
          <Sidebar />
          <main className="flex-1 overflow-y-auto bg-[var(--color-bg-base)] pb-24 md:pb-8">
            <Outlet />
          </main>
        </div>
        <BottomTabNav />
        <FloatingAIButton />
      </div>
    </RequireAuth>
  )
}
