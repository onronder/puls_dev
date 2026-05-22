import type { LucideIcon } from 'lucide-react'
import type { ReactNode } from 'react'

import { cn } from '#/lib/utils'

type EmptyStateProps = {
  icon?: LucideIcon
  title: string
  description?: string
  action?: ReactNode
  className?: string
}

export function EmptyState({ icon: Icon, title, description, action, className }: EmptyStateProps) {
  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center rounded-2xl border border-dashed border-[var(--color-border)] bg-[var(--color-bg-surface)] px-6 py-10 text-center',
        className,
      )}
    >
      {Icon ? (
        <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-[var(--color-bg-elevated)]">
          <Icon className="h-6 w-6 text-[var(--color-text-muted)]" />
        </div>
      ) : null}
      <h3 className="text-base font-semibold text-[var(--color-text-primary)]">{title}</h3>
      {description ? (
        <p className="mt-2 max-w-sm text-sm leading-relaxed text-[var(--color-text-muted)]">
          {description}
        </p>
      ) : null}
      {action ? <div className="mt-4">{action}</div> : null}
    </div>
  )
}
