import { Outlet, createFileRoute, redirect } from '@tanstack/react-router'

import { AppHeader } from '#/components/layout/AppHeader'
import { BottomTabNav } from '#/components/layout/BottomTabNav'
import { FloatingAIButton } from '#/components/layout/FloatingAIButton'
import { Sidebar } from '#/components/layout/Sidebar'
import { supabase } from '#/lib/supabase'

export const Route = createFileRoute('/_app')({
  beforeLoad: async ({ location }) => {
    const { data } = await supabase.auth.getSession()
    if (!data.session) {
      throw redirect({
        to: '/login',
        search: { redirect: location.href },
      })
    }
  },
  component: AppLayout,
})

function AppLayout() {
  return (
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
  )
}
