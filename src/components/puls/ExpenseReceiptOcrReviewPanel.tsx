import { Check, FileQuestion, Loader2, PencilLine, ScanText, X } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Textarea } from '#/components/ui/textarea'
import type {
  ExpenseReceiptOcrReview,
  ExpenseReceiptOcrReviewDecision,
} from '#/lib/data'
import { cn } from '#/lib/utils'

type ExpenseReceiptOcrReviewPanelProps = {
  reviews: readonly ExpenseReceiptOcrReview[]
  canReview?: boolean
  isSubmitting?: boolean
  onReview?: (input: {
    resultId: string
    reviewStatus: ExpenseReceiptOcrReviewDecision
    reviewNote?: string | null
  }) => void
  className?: string
}

const REVIEW_FIELD_ORDER = [
  'amount',
  'currency',
  'expense_date',
  'category_label',
  'merchant_name',
  'vat_included',
] as const

function reviewStatusTone(status: ExpenseReceiptOcrReview['reviewStatus']): StatusTone {
  switch (status) {
    case 'accepted':
      return 'success'
    case 'corrected':
      return 'info'
    case 'rejected':
    case 'needs_new_document':
      return 'danger'
    case 'pending_review':
      return 'warning'
    default:
      return 'neutral'
  }
}

function formatReviewValue(value: unknown): string {
  if (value === null || value === undefined) return '—'
  if (typeof value === 'boolean') return value ? '✓' : '—'
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : '—'
  if (typeof value === 'string') return value.trim() || '—'
  return '—'
}

function formatConfidence(value: number | null): string | null {
  if (!Number.isFinite(value ?? Number.NaN) || value === null) return null
  return `${Math.round(value * 100)}%`
}

export function ExpenseReceiptOcrReviewPanel({
  reviews,
  canReview = false,
  isSubmitting = false,
  onReview,
  className,
}: ExpenseReceiptOcrReviewPanelProps) {
  const { t, i18n } = useTranslation()
  const [reviewNote, setReviewNote] = useState('')
  const review = reviews[0]
  const visibleFields = useMemo(() => {
    if (!review) return []
    const fields = REVIEW_FIELD_ORDER.flatMap((field) =>
      field in review.extractedFields
        ? [
            {
              key: field,
              value: review.extractedFields[field],
              confidence: review.fieldConfidence[field] ?? null,
            },
          ]
        : [],
    )
    return fields.slice(0, 6)
  }, [review])

  if (!review) return null

  const isPending = review.reviewStatus === 'pending_review'
  const confidenceLabel = formatConfidence(review.documentConfidence)
  const canSubmitReview = canReview && isPending && Boolean(onReview)
  const trimmedNote = reviewNote.trim()
  const reviewedAtLabel = review.reviewedAt
    ? new Intl.DateTimeFormat(i18n.language, {
        day: '2-digit',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      }).format(new Date(review.reviewedAt))
    : null

  function submitReview(reviewStatus: ExpenseReceiptOcrReviewDecision) {
    onReview?.({
      resultId: review.id,
      reviewStatus,
      reviewNote: trimmedNote || null,
    })
  }

  return (
    <div
      className={cn(
        'mt-2 rounded-md border border-border bg-surface-2 p-3 text-[12px]',
        className,
      )}
    >
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="flex min-w-0 items-center gap-2">
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-ai-soft text-ai">
            <ScanText className="h-3.5 w-3.5" />
          </span>
          <div className="min-w-0">
            <div className="text-[13px] font-semibold text-foreground">
              {t('workflowEvidence.ocr.title')}
            </div>
            <div className="text-muted-foreground">{t('workflowEvidence.ocr.boundary')}</div>
          </div>
        </div>
        <StatusPill tone={reviewStatusTone(review.reviewStatus)} className="min-h-7">
          {t(`workflowEvidence.ocr.status.${review.reviewStatus}`)}
        </StatusPill>
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-2 text-muted-foreground">
        {confidenceLabel ? (
          <span>{t('workflowEvidence.ocr.confidence', { value: confidenceLabel })}</span>
        ) : null}
        {review.providerClass ? (
          <span>
            {t('workflowEvidence.ocr.provider', {
              provider: review.providerName ?? review.providerClass,
            })}
          </span>
        ) : null}
        {review.duplicateOfResultId ? (
          <StatusPill tone="warning" className="min-h-6 text-[10px]">
            {t('workflowEvidence.ocr.duplicate')}
          </StatusPill>
        ) : null}
      </div>

      {review.mismatchFlags.length > 0 ? (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {review.mismatchFlags.slice(0, 4).map((flag) => (
            <StatusPill key={flag} tone="warning" className="min-h-6 text-[10px]">
              {t(`workflowEvidence.ocr.flags.${flag}`, { defaultValue: flag })}
            </StatusPill>
          ))}
        </div>
      ) : null}

      {visibleFields.length > 0 ? (
        <dl className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-2">
          {visibleFields.map((field) => {
            const fieldConfidence = formatConfidence(field.confidence)
            return (
              <div key={field.key} className="min-w-0 rounded-md border border-border bg-card px-2.5 py-2">
                <dt className="truncate text-[11px] font-medium text-muted-foreground">
                  {t(`workflowEvidence.ocr.fields.${field.key}`)}
                  {fieldConfidence ? (
                    <span className="ml-1 font-normal">· {fieldConfidence}</span>
                  ) : null}
                </dt>
                <dd className="mt-0.5 truncate text-[13px] font-semibold text-foreground">
                  {formatReviewValue(field.value)}
                </dd>
              </div>
            )
          })}
        </dl>
      ) : (
        <p className="mt-3 text-muted-foreground">{t('workflowEvidence.ocr.noSuggestions')}</p>
      )}

      {review.reviewNote ? (
        <p className="mt-3 rounded-md border border-border bg-card px-2.5 py-2 text-muted-foreground">
          {review.reviewNote}
        </p>
      ) : null}

      {reviewedAtLabel ? (
        <p className="mt-2 text-muted-foreground">
          {t('workflowEvidence.ocr.reviewedAt', { value: reviewedAtLabel })}
        </p>
      ) : null}

      {canSubmitReview ? (
        <div className="mt-3 space-y-2">
          <Textarea
            rows={2}
            value={reviewNote}
            onChange={(event) => setReviewNote(event.target.value)}
            placeholder={t('workflowEvidence.ocr.notePlaceholder')}
            className="min-h-[68px] text-[13px]"
          />
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <Button
              type="button"
              size="sm"
              className="min-h-10"
              disabled={isSubmitting}
              onClick={() => submitReview('accepted')}
            >
              {isSubmitting ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Check className="h-3.5 w-3.5" />}
              {t('workflowEvidence.ocr.actions.accept')}
            </Button>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="min-h-10"
              disabled={isSubmitting || trimmedNote.length === 0}
              onClick={() => submitReview('corrected')}
            >
              <PencilLine className="h-3.5 w-3.5" />
              {t('workflowEvidence.ocr.actions.corrected')}
            </Button>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="min-h-10"
              disabled={isSubmitting}
              onClick={() => submitReview('rejected')}
            >
              <X className="h-3.5 w-3.5" />
              {t('workflowEvidence.ocr.actions.reject')}
            </Button>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="min-h-10"
              disabled={isSubmitting}
              onClick={() => submitReview('needs_new_document')}
            >
              <FileQuestion className="h-3.5 w-3.5" />
              {t('workflowEvidence.ocr.actions.needsNewDocument')}
            </Button>
          </div>
        </div>
      ) : null}
    </div>
  )
}
