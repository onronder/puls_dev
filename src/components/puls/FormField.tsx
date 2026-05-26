import type { ReactNode } from 'react'

import { Label } from '#/components/ui/label'
import { cn } from '#/lib/utils'

type FormFieldProps = {
  label: string
  htmlFor?: string
  hint?: string
  error?: string
  required?: boolean
  children: ReactNode
  className?: string
}

export function FormField({
  label,
  htmlFor,
  hint,
  error,
  required,
  children,
  className,
}: FormFieldProps) {
  return (
    <div className={cn('space-y-2', className)}>
      <Label htmlFor={htmlFor} className="text-sm font-medium text-[var(--color-text-secondary)]">
        {label}
        {required ? <span className="ml-1 text-[var(--color-danger)]">*</span> : null}
      </Label>
      {children}
      {hint && !error ? (
        <p
          id={htmlFor ? `${htmlFor}-hint` : undefined}
          className="text-xs leading-relaxed text-[var(--color-text-muted)]"
        >
          {hint}
        </p>
      ) : null}
      {error ? (
        <p id={htmlFor ? `${htmlFor}-error` : undefined} className="text-xs text-[var(--color-danger)]">
          {error}
        </p>
      ) : null}
    </div>
  )
}
