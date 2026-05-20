import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '#/components/ui/card'

export const Route = createFileRoute('/_app/dashboard')({
  component: DashboardPage,
})

function DashboardPage() {
  const { t } = useTranslation()

  return (
    <div className="mx-auto max-w-5xl p-4 md:p-8">
      <div className="mb-6">
        <h1 className="text-2xl font-bold md:text-3xl">{t('dashboard.title')}</h1>
        <p className="mt-2 text-[var(--color-text-muted)]">{t('dashboard.placeholder')}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Bağla™</CardTitle>
            <CardDescription>Ekip bağlılık sinyalleri (k≥5)</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="font-mono text-3xl font-bold text-[var(--color-primary)]">—</p>
            <p className="mt-2 text-xs text-[var(--color-text-muted)]">Sprint-2: sentiment-engine</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-base">KPI</CardTitle>
            <CardDescription>Pozisyon hedefleri</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="font-mono text-3xl font-bold">—</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-base">AI Koç™</CardTitle>
            <CardDescription>Floating widget aktif</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-[var(--color-text-secondary)]">
              Sağ alttaki butondan erişilebilir
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
