import type { ReactNode } from 'react'

import { cn } from '#/lib/utils'

type PageHeaderProps = {
  title: string
  subtitle?: string
  badge?: ReactNode
  actions?: ReactNode
  className?: string
}

export function PageHeader({ title, subtitle, badge, actions, className }: PageHeaderProps) {
  return (
    <header
      className={cn(
        'mb-6 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between',
        className,
      )}
    >
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <h1 className="text-[26px] font-semibold tracking-tight text-[var(--color-text-primary)] sm:text-3xl">
            {title}
          </h1>
          {badge}
        </div>
        {subtitle ? (
          <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">{subtitle}</p>
        ) : null}
      </div>
      {actions ? <div className="flex shrink-0 flex-wrap items-center gap-2">{actions}</div> : null}
    </header>
  )
}
