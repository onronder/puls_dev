import { cn } from '#/lib/utils'

type ProgressProps = {
  value?: number
  className?: string
}

export function Progress({ value = 0, className }: ProgressProps) {
  const clamped = Math.min(100, Math.max(0, value))
  return (
    <div
      className={cn(
        'relative h-2 w-full overflow-hidden rounded-full bg-[var(--color-bg-elevated)]',
        className,
      )}
      role="progressbar"
      aria-valuenow={clamped}
      aria-valuemin={0}
      aria-valuemax={100}
    >
      <div
        className="h-full rounded-full bg-[var(--color-primary)] transition-all"
        style={{ width: `${clamped}%` }}
      />
    </div>
  )
}
