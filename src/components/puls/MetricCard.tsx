import type { LucideIcon } from 'lucide-react'

import { cn } from '#/lib/utils'

type MetricCardProps = {
  label: string
  value: string
  hint?: string
  icon?: LucideIcon
  trend?: string
  className?: string
  compact?: boolean
}

export function MetricCard({
  label,
  value,
  hint,
  icon: Icon,
  trend,
  className,
  compact,
}: MetricCardProps) {
  return (
    <div
      className={cn(
        'min-w-0 shrink-0 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4',
        compact ? 'min-w-[140px]' : 'w-full',
        className,
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <p className="text-xs font-medium text-[var(--color-text-muted)]">{label}</p>
        {Icon ? (
          <Icon className="h-4 w-4 shrink-0 text-[var(--color-primary)] opacity-80" />
        ) : null}
      </div>
      <p className="mt-2 truncate font-mono text-2xl font-bold tracking-tight">{value}</p>
      {trend ? (
        <p className="mt-1 text-xs font-medium text-[var(--color-primary-muted)]">{trend}</p>
      ) : null}
      {hint ? <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-muted)]">{hint}</p> : null}
    </div>
  )
}
