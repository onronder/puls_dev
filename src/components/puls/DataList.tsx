import type { ReactNode } from 'react'

import { cn } from '#/lib/utils'

export type DataListItem = {
  id: string
  title: string
  subtitle?: string
  meta?: string
  leading?: ReactNode
  trailing?: ReactNode
  onClick?: () => void
}

type DataListProps = {
  items: DataListItem[]
  className?: string
  emptyLabel?: string
}

export function DataList({ items, className, emptyLabel }: DataListProps) {
  if (items.length === 0 && emptyLabel) {
    return (
      <p className="rounded-lg border border-dashed border-[var(--color-border)] px-4 py-6 text-center text-sm text-[var(--color-text-muted)]">
        {emptyLabel}
      </p>
    )
  }

  return (
    <ul className={cn('divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]', className)}>
      {items.map((item) => (
        <li key={item.id}>
          <button
            type="button"
            onClick={item.onClick}
            disabled={!item.onClick}
            className={cn(
              'flex w-full min-w-0 touch-target items-center gap-3 px-4 py-3 text-left transition-colors',
              item.onClick ? 'hover:bg-[var(--color-bg-elevated)]' : 'cursor-default',
            )}
          >
            {item.leading ? <div className="shrink-0">{item.leading}</div> : null}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium">{item.title}</p>
              {item.subtitle ? (
                <p className="truncate text-xs text-[var(--color-text-muted)]">{item.subtitle}</p>
              ) : null}
            </div>
            {item.meta ? (
              <span className="shrink-0 text-xs font-medium text-[var(--color-text-secondary)]">
                {item.meta}
              </span>
            ) : null}
            {item.trailing ? <div className="shrink-0">{item.trailing}</div> : null}
          </button>
        </li>
      ))}
    </ul>
  )
}
