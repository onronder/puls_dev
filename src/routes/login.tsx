import { createFileRoute, redirect, useNavigate } from '@tanstack/react-router'
import { Sparkles } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '#/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '#/components/ui/card'
import { Input } from '#/components/ui/input'
import { Label } from '#/components/ui/label'
import { useAuth } from '#/lib/auth'
import { supabase } from '#/lib/supabase'

export const Route = createFileRoute('/login')({
  beforeLoad: async () => {
    const { data } = await supabase.auth.getSession()
    if (data.session) {
      throw redirect({ to: '/dashboard' })
    }
  },
  component: LoginPage,
})

function LoginPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { signIn } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    const result = await signIn(email, password)
    setLoading(false)
    if (result.error) {
      setError(result.error)
      return
    }
    void navigate({ to: '/dashboard' })
  }

  return (
    <div className="puls-login-bg flex min-h-screen flex-col lg:flex-row">
      <section className="relative hidden flex-1 flex-col justify-between p-10 lg:flex">
        <div>
          <p className="text-3xl font-bold tracking-tight text-[var(--color-text-primary)]">
            PULS<span className="text-[var(--color-primary)]">.</span>
          </p>
          <p className="mt-6 max-w-md text-base leading-relaxed text-[var(--color-text-secondary)]">
            {t('app.tagline')}
          </p>
        </div>
        <div className="max-w-sm rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-5 backdrop-blur-xl">
          <div className="flex items-start gap-3">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
              <Sparkles className="h-5 w-5" />
            </span>
            <div>
              <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                {t('ai.teaser.title')}
              </p>
              <p className="mt-1 text-[11px] leading-relaxed text-[var(--color-text-muted)]">
                {t('ai.teaser.description')}
              </p>
            </div>
          </div>
        </div>
        <p className="text-[11px] text-[var(--color-text-muted)]">v1.0 · FOUNDATION</p>
      </section>

      <section className="flex flex-1 flex-col items-center justify-center p-4 sm:p-6">
        <div className="mb-8 text-center lg:hidden">
          <p className="text-2xl font-bold tracking-tight text-[var(--color-text-primary)]">
            PULS<span className="text-[var(--color-primary)]">.</span>
          </p>
          <p className="mt-2 text-sm text-[var(--color-text-muted)]">{t('app.tagline')}</p>
        </div>

        <Card className="w-full max-w-md border-[var(--color-border-strong)]">
          <CardHeader>
            <CardTitle className="text-xl">{t('auth.loginTitle')}</CardTitle>
            <CardDescription>{t('auth.kvkkNotice')}</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={(e) => void handleSubmit(e)} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="email">{t('auth.email')}</Label>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">{t('auth.password')}</Label>
                <Input
                  id="password"
                  type="password"
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </div>
              {error ? (
                <p className="rounded-lg border border-[var(--color-danger-soft)] bg-[var(--color-danger-soft)] px-3 py-2 text-sm text-[var(--color-danger)]">
                  {error}
                </p>
              ) : null}
              <Button type="submit" className="min-h-11 w-full" size="lg" disabled={loading}>
                {loading ? t('auth.signingIn') : t('auth.signIn')}
              </Button>
            </form>
          </CardContent>
        </Card>
      </section>
    </div>
  )
}
