import { CheckCircle2, FileUp, Loader2, X } from 'lucide-react'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import {
  getWorkflowEvidenceFilePolicy,
  validateWorkflowEvidenceFile,
  type WorkflowEvidenceDomain,
  type WorkflowEvidenceUpload,
} from '#/lib/data'

type EvidenceUploadFieldProps = {
  id: string
  domain: WorkflowEvidenceDomain
  value: WorkflowEvidenceUpload | null
  required?: boolean
  disabled?: boolean
  isUploading?: boolean
  error?: string
  onUpload: (file: File) => void
  onRemove: () => void
}

function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 KB'
  const mb = bytes / (1024 * 1024)
  if (mb >= 1) return `${mb.toFixed(mb >= 10 ? 0 : 1)} MB`
  return `${Math.ceil(bytes / 1024)} KB`
}

export function EvidenceUploadField({
  id,
  domain,
  value,
  required = false,
  disabled = false,
  isUploading = false,
  error,
  onUpload,
  onRemove,
}: EvidenceUploadFieldProps) {
  const { t } = useTranslation()
  const inputRef = useRef<HTMLInputElement>(null)
  const [localError, setLocalError] = useState<string | null>(null)
  const policy = getWorkflowEvidenceFilePolicy(domain)
  const visibleError = error ?? localError

  function handleFileChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    event.target.value = ''
    setLocalError(null)
    if (!file) return

    const validation = validateWorkflowEvidenceFile(domain, file)
    if (validation === 'type') {
      setLocalError(t('workflowEvidence.error.fileType'))
      return
    }
    if (validation === 'size') {
      setLocalError(t('workflowEvidence.error.fileSize'))
      return
    }
    onUpload(file)
  }

  return (
    <div className="space-y-2">
      <input
        ref={inputRef}
        id={id}
        type="file"
        accept={policy.accept}
        disabled={disabled || isUploading}
        className="sr-only"
        onChange={handleFileChange}
      />

      {value ? (
        <div className="flex min-h-12 items-center gap-3 rounded-md border border-border bg-surface-2 px-3 py-2">
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-success/10 text-success">
            <CheckCircle2 className="h-4 w-4" />
          </span>
          <div className="min-w-0 flex-1">
            <div className="truncate text-[13px] font-medium text-foreground">{value.fileName}</div>
            <div className="text-[12px] text-muted-foreground">
              {formatBytes(value.fileSizeBytes)}
            </div>
          </div>
          <StatusPill tone="success" className="hidden sm:inline-flex">
            {t('workflowEvidence.ready')}
          </StatusPill>
          <Button
            type="button"
            variant="ghost"
            size="icon"
            className="h-9 w-9 shrink-0"
            disabled={disabled || isUploading}
            aria-label={t('workflowEvidence.remove')}
            onClick={() => {
              setLocalError(null)
              onRemove()
            }}
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      ) : (
        <Button
          type="button"
          variant="outline"
          className="min-h-12 w-full justify-start gap-3 border-dashed px-3 text-left"
          disabled={disabled || isUploading}
          onClick={() => inputRef.current?.click()}
        >
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-surface-2 text-muted-foreground">
            {isUploading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <FileUp className="h-4 w-4" />
            )}
          </span>
          <span className="min-w-0 flex-1">
            <span className="block truncate text-[13px] font-medium">
              {isUploading ? t('workflowEvidence.uploading') : t('workflowEvidence.choose')}
            </span>
            <span className="block truncate text-[12px] text-muted-foreground">
              {required
                ? t('workflowEvidence.requiredHint', { size: formatBytes(policy.maxBytes) })
                : t('workflowEvidence.optionalHint', { size: formatBytes(policy.maxBytes) })}
            </span>
          </span>
        </Button>
      )}

      {visibleError ? (
        <p className="text-[12px] leading-relaxed text-[var(--color-danger)]">{visibleError}</p>
      ) : null}
    </div>
  )
}
