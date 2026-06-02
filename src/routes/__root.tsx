import { HeadContent, Outlet, Scripts, createRootRoute } from '@tanstack/react-router'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import * as Sentry from '@sentry/react'
import { Toaster } from 'sonner'

import { AppErrorFallback } from '#/components/puls/AppErrorFallback'
import { AuthProvider } from '#/lib/auth'
import { initObservability } from '#/lib/observability/sentry'
import '#/i18n'

import appCss from '../styles.css?url'

const queryClient = new QueryClient()

initObservability()

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover' },
      { title: 'PULS AI Coach' },
    ],
    links: [{ rel: 'stylesheet', href: appCss }],
  }),
  component: RootComponent,
})

function RootComponent() {
  return (
    <RootDocument>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <Sentry.ErrorBoundary
            fallback={({ resetError }) => <AppErrorFallback onReset={resetError} />}
          >
            <Outlet />
          </Sentry.ErrorBoundary>
          <Toaster theme="dark" position="top-center" richColors />
        </AuthProvider>
      </QueryClientProvider>
    </RootDocument>
  )
}

function RootDocument({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tr">
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  )
}
