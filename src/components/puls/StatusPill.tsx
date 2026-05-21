import { cn } from '#/lib/utils'

export type StatusTone = 'success' | 'warning' | 'danger' | 'info' | 'neutral' | 'ai'

const toneStyles: Record<StatusTone, string> = {
  success: 'border-[rgba(22,163,74,0.35)] bg-[rgba(22,163,74,0.12)] text-[#86efac]',
  warning: 'border-[rgba(245,158,11,0.35)] bg-[rgba(245,158,11,0.12)] text-[#fcd34d]',
  danger: 'border-[rgba(232,40,78,0.35)] bg-[rgba(232,40,78,0.12)] text-[#fda4af]',
  info: 'border-[rgba(13,148,136,0.35)] bg-[rgba(13,148,136,0.12)] text-[#5eead4]',
  neutral: 'border-[var(--color-border)] bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]',
  ai: 'border-[rgba(124,58,237,0.35)] bg-[rgba(124,58,237,0.12)] text-[#c4b5fd]',
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
        'inline-flex min-h-[28px] items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold',
        toneStyles[tone],
        className,
      )}
    >
      {children}
    </span>
  )
}
