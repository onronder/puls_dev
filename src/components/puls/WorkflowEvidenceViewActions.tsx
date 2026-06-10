import { Eye, Loader2 } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '#/components/ui/button'
import {
  createWorkflowEvidenceSignedUrl,
  type WorkflowEvidenceAttachment,
} from '#/lib/data'
import { cn } from '#/lib/utils'

type WorkflowEvidenceViewActionsProps = {
  items: readonly WorkflowEvidenceAttachment[]
  className?: string
  buttonClassName?: string
  compact?: boolean
}

function formatBytes(bytes: number | null): string | null {
  if (!Number.isFinite(bytes ?? Number.NaN) || !bytes || bytes <= 0) return null
  const mb = bytes / (1024 * 1024)
  if (mb >= 1) return `${mb.toFixed(mb >= 10 ? 0 : 1)} MB`
  return `${Math.ceil(bytes / 1024)} KB`
}

export function WorkflowEvidenceViewActions({
  items,
  className,
  buttonClassName,
  compact = false,
}: WorkflowEvidenceViewActionsProps) {
  const { t } = useTranslation()
  const [openingId, setOpeningId] = useState<string | null>(null)

  if (items.length === 0) return null

  async function openEvidence(attachment: WorkflowEvidenceAttachment) {
    setOpeningId(attachment.id)
    try {
      const signedUrl = await createWorkflowEvidenceSignedUrl(attachment)
      const anchor = document.createElement('a')
      anchor.href = signedUrl
      anchor.target = '_blank'
      anchor.rel = 'noopener noreferrer'
      document.body.appendChild(anchor)
      anchor.click()
      anchor.remove()
    } catch {
      toast.error(t('workflowEvidence.error.viewFailed'))
    } finally {
      setOpeningId(null)
    }
  }

  return (
    <div className={cn('flex min-w-0 flex-wrap items-center gap-2', className)}>
      {items.map((attachment) => {
        const isOpening = openingId === attachment.id
        const fileSize = formatBytes(attachment.fileSizeBytes)

        return (
          <Button
            key={attachment.id}
            type="button"
            variant="outline"
            size="sm"
            className={cn(
              'min-h-9 max-w-full gap-1.5 px-2.5 text-[12px]',
              compact ? 'h-8 min-h-8' : null,
              buttonClassName,
            )}
            disabled={openingId !== null}
            aria-label={t('workflowEvidence.viewFile', { file: attachment.fileName })}
            title={attachment.fileName}
            onClick={(event) => {
              event.stopPropagation()
              void openEvidence(attachment)
            }}
          >
            {isOpening ? (
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <Eye className="h-3.5 w-3.5" />
            )}
            <span className="truncate">
              {items.length === 1 ? t('workflowEvidence.view') : attachment.fileName}
            </span>
            {fileSize && !compact ? (
              <span className="hidden shrink-0 text-muted-foreground sm:inline">· {fileSize}</span>
            ) : null}
          </Button>
        )
      })}
    </div>
  )
}
