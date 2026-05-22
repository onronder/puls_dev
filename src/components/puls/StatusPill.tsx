import { cn } from '#/lib/utils'

export type StatusTone = 'success' | 'warning' | 'danger' | 'info' | 'neutral' | 'ai'

const toneStyles: Record<StatusTone, string> = {
  success:
    'border-[color-mix(in_srgb,var(--color-success)_30%,transparent)] bg-[var(--color-success-soft)] text-[var(--color-success)]',
  warning:
    'border-[color-mix(in_srgb,var(--color-warning)_30%,transparent)] bg-[var(--color-warning-soft)] text-[var(--color-warning)]',
  danger:
    'border-[color-mix(in_srgb,var(--color-danger)_30%,transparent)] bg-[var(--color-danger-soft)] text-[var(--color-danger)]',
  info: 'border-[color-mix(in_srgb,var(--color-primary)_28%,transparent)] bg-[var(--color-info-soft)] text-[var(--color-info)]',
  neutral:
    'border-[var(--color-border)] bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]',
  ai: 'border-[color-mix(in_srgb,var(--color-ai)_28%,transparent)] bg-[var(--color-ai-soft)] text-[var(--color-ai)]',
}

type StatusPillProps = {
  children: React.ReactNode
  tone?: StatusTone
  className?: string
}

export function StatusPill({ children, tone = 'neutral', className }: StatusPillProps) {
  return (
    <span
      className={cn(
        'inline-flex min-h-[28px] items-center rounded-full border px-2.5 py-0.5 text-[11px] font-semibold',
        toneStyles[tone],
        className,
      )}
    >
      {children}
    </span>
  )
}
