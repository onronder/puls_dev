import type * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'

import { cn } from '#/lib/utils'

const badgeVariants = cva(
  'inline-flex items-center rounded-md border px-2 py-0.5 text-[11px] font-semibold transition-colors',
  {
    variants: {
      variant: {
        default:
          'border-transparent bg-[var(--color-primary)] text-[var(--color-primary-foreground)]',
        secondary:
          'border-[var(--color-border)] bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]',
        outline: 'border-[var(--color-border)] text-[var(--color-text-muted)]',
        ai: 'border-transparent bg-[var(--color-ai-soft)] text-[var(--color-ai)]',
        success:
          'border-transparent bg-[var(--color-success-soft)] text-[var(--color-success)]',
        warning:
          'border-transparent bg-[var(--color-warning-soft)] text-[var(--color-warning)]',
        danger:
          'border-transparent bg-[var(--color-danger-soft)] text-[var(--color-danger)]',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
)

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />
}
