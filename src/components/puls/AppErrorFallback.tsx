import { AlertTriangle, Home, RotateCw } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { Button } from '#/components/ui/button'

export function AppErrorFallback({ onReset }: { onReset?: () => void }) {
  const { t } = useTranslation()

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--color-bg-base)] p-4">
      <section className="w-full max-w-md rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-6 text-center">
        <span className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-[var(--color-warning-soft)] text-[var(--color-warning)]">
          <AlertTriangle className="h-6 w-6" aria-hidden />
        </span>
        <h1 className="mt-4 text-xl font-semibold text-[var(--color-text-primary)]">
          {t('appError.title')}
        </h1>
        <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
          {t('appError.description')}
        </p>
        <div className="mt-5 flex flex-col gap-2 sm:flex-row sm:justify-center">
          <Button
            type="button"
            className="touch-target"
            onClick={() => {
              onReset?.()
              window.location.reload()
            }}
          >
            <RotateCw className="h-4 w-4" />
            {t('appError.reload')}
          </Button>
          <Button
            type="button"
            variant="outline"
            className="touch-target"
            onClick={() => {
              onReset?.()
              window.location.assign('/dashboard')
            }}
          >
            <Home className="h-4 w-4" />
            {t('appError.dashboard')}
          </Button>
        </div>
      </section>
    </div>
  )
}
