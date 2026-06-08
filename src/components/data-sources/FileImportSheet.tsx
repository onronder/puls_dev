import {
  AlertTriangle,
  Download,
  FileCheck2,
  FileSpreadsheet,
  Plug,
  SearchCheck,
} from 'lucide-react'
import type { ChangeEvent } from 'react'
import { useTranslation } from 'react-i18next'

import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import {
  buildFileImportExpectedFileName,
  type FileImportPackageResult,
  type FileImportScopeId,
} from '#/lib/data/setup/file-import-contract'
import { cn } from '#/lib/utils'

type FileImportScopeOption = {
  id: FileImportScopeId
  labelKey: string
}

type FileImportSheetProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  onClose: () => void
  sourceLabel: string
  sourceReady: boolean
  scopes: FileImportScopeOption[]
  selectedScope: FileImportScopeId
  onScopeChange: (scope: FileImportScopeId) => void
  packageResult: FileImportPackageResult | null
  errorCount: number
  warningCount: number
  staged: boolean
  stagedBatchCount: number
  parsing: boolean
  primaryDisabled: boolean
  primaryLabel: string
  onPrimaryAction: () => void
  onFileChange: (event: ChangeEvent<HTMLInputElement>) => void
  onDownloadTemplate: (scope: FileImportScopeId) => void
  onDownloadAllTemplates: (scopes: FileImportScopeId[]) => void
}

function fileImportIssueLabelKey(code: string): string {
  return `erp.fileImport.issues.${code}`
}

function formatFileImportDelimiter(
  delimiter: FileImportPackageResult['files'][number]['parseResult']['delimiter'],
): string {
  if (delimiter === '\t') return 'Tab'
  return delimiter ?? '-'
}

export function FileImportSheet({
  open,
  onOpenChange,
  onClose,
  sourceLabel,
  sourceReady,
  scopes,
  selectedScope,
  onScopeChange,
  packageResult,
  errorCount,
  warningCount,
  staged,
  stagedBatchCount,
  parsing,
  primaryDisabled,
  primaryLabel,
  onPrimaryAction,
  onFileChange,
  onDownloadTemplate,
  onDownloadAllTemplates,
}: FileImportSheetProps) {
  const { t } = useTranslation()

  return (
    <SheetShell
      open={open}
      onOpenChange={onOpenChange}
      title={t('erp.fileImport.title')}
      description={t('erp.fileImport.description')}
      className="w-[calc(100vw-1rem)] sm:inset-x-auto sm:bottom-4 sm:left-auto sm:right-4 sm:top-4 sm:mt-0 sm:h-auto sm:max-h-none sm:w-[min(720px,calc(100vw-2rem))] sm:rounded-2xl"
      footer={
        <div className="flex w-full flex-col gap-2 sm:flex-row sm:justify-end">
          <Button
            type="button"
            variant="outline"
            className="touch-target w-full sm:w-auto"
            onClick={onClose}
          >
            {t('erp.fileImport.actions.close')}
          </Button>
          <Button
            type="button"
            className="touch-target w-full sm:w-auto"
            disabled={primaryDisabled}
            aria-disabled={primaryDisabled}
            onClick={onPrimaryAction}
          >
            {staged ? (
              <SearchCheck className="h-4 w-4" />
            ) : sourceReady ? (
              <FileCheck2 className="h-4 w-4" />
            ) : (
              <Plug className="h-4 w-4" />
            )}
            {primaryLabel}
          </Button>
        </div>
      }
    >
      <div className="space-y-4">
        <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                {t('erp.fileImport.source')}
              </p>
              <h3 className="mt-2 text-lg font-semibold text-[var(--color-text-primary)]">
                {sourceLabel}
              </h3>
              <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-muted)]">
                {sourceReady ? t('erp.fileImport.sourceReady') : t('erp.fileImport.sourceRequired')}
              </p>
            </div>
            <StatusPill tone={sourceReady ? 'success' : 'warning'}>
              {sourceReady ? t('erp.readinessStatus.ready') : t('erp.readinessStatus.partial')}
            </StatusPill>
          </div>
        </div>

        <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
            {t('erp.fileImport.scopeTitle')}
          </p>
          <div className="mt-3 grid gap-2 sm:grid-cols-2">
            {scopes.map((scope) => {
              const selected = scope.id === selectedScope
              return (
                <button
                  key={scope.id}
                  type="button"
                  aria-pressed={selected}
                  onClick={() => onScopeChange(scope.id)}
                  className={cn(
                    'touch-target rounded-lg border px-3 py-2 text-left text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary)]',
                    selected
                      ? 'border-[color-mix(in_srgb,var(--color-primary)_55%,transparent)] bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
                      : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)] hover:border-[color-mix(in_srgb,var(--color-primary)_28%,transparent)]',
                  )}
                >
                  {t(scope.labelKey)}
                </button>
              )
            })}
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
            <p className="text-sm font-semibold text-[var(--color-text-primary)]">
              {t('erp.fileImport.templateTitle')}
            </p>
            <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-muted)]">
              {t('erp.fileImport.templateDescription', {
                fileName: buildFileImportExpectedFileName(selectedScope),
              })}
            </p>
            <div className="mt-4 grid gap-2">
              <Button
                type="button"
                variant="outline"
                className="touch-target w-full"
                onClick={() => onDownloadTemplate(selectedScope)}
              >
                <Download className="h-4 w-4" />
                {t('erp.fileImport.actions.downloadTemplate')}
              </Button>
              <Button
                type="button"
                variant="outline"
                className="touch-target w-full"
                onClick={() => onDownloadAllTemplates(scopes.map((scope) => scope.id))}
              >
                <Download className="h-4 w-4" />
                {t('erp.fileImport.actions.downloadAllTemplates')}
              </Button>
            </div>
          </div>

          <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
            <p className="text-sm font-semibold text-[var(--color-text-primary)]">
              {t('erp.fileImport.fileTitle')}
            </p>
            <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-muted)]">
              {t('erp.fileImport.fileDescription')}
            </p>
            <label className="touch-target mt-4 flex cursor-pointer items-center justify-center gap-2 rounded-lg border border-dashed border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-3 text-sm font-semibold text-[var(--color-text-primary)] transition-colors hover:border-[color-mix(in_srgb,var(--color-primary)_35%,transparent)]">
              <FileSpreadsheet className="h-4 w-4" aria-hidden />
              {parsing
                ? t('erp.fileImport.actions.parsing')
                : t('erp.fileImport.actions.chooseFile')}
              <input
                type="file"
                accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                multiple
                className="sr-only"
                disabled={parsing}
                onChange={onFileChange}
              />
            </label>
          </div>
        </div>

        {packageResult ? (
          <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                  {packageResult.ok
                    ? t('erp.fileImport.contractReady')
                    : t('erp.fileImport.contractBlocked')}
                </p>
                <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                  {t('erp.fileImport.packageSummary', {
                    files: packageResult.fileCount,
                    rows: packageResult.rowCount,
                  })}
                </p>
              </div>
              <StatusPill tone={packageResult.ok ? 'success' : 'danger'}>
                {packageResult.ok
                  ? t('erp.readinessStatus.ready')
                  : t('erp.readinessStatus.blocked')}
              </StatusPill>
            </div>

            <div className="mt-4 grid gap-2 sm:grid-cols-4">
              <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                <p className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {t('erp.fileImport.metrics.files')}
                </p>
                <p className="mt-1 text-lg font-semibold text-[var(--color-text-primary)]">
                  {packageResult.fileCount}
                </p>
              </div>
              <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                <p className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {t('erp.fileImport.metrics.rows')}
                </p>
                <p className="mt-1 text-lg font-semibold text-[var(--color-text-primary)]">
                  {packageResult.rowCount}
                </p>
              </div>
              <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                <p className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {t('erp.fileImport.metrics.readyFiles')}
                </p>
                <p className="mt-1 text-lg font-semibold text-[var(--color-text-primary)]">
                  {packageResult.readyFileCount}
                </p>
              </div>
              <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                <p className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {t('erp.fileImport.metrics.findings')}
                </p>
                <p className="mt-1 text-lg font-semibold text-[var(--color-text-primary)]">
                  {errorCount} / {warningCount}
                </p>
              </div>
            </div>

            <ul className="mt-4 divide-y divide-[var(--color-border)] rounded-lg border border-[var(--color-border)]">
              {packageResult.files.map((item) => (
                <li key={item.fileName} className="flex items-start justify-between gap-3 p-3">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold text-[var(--color-text-primary)]">
                      {item.fileName}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {item.scope
                        ? t(`erp.fileImport.scopes.${item.scope}`)
                        : t('erp.fileImport.unknownScope')}{' '}
                      · {item.parseResult.rowCount} {t('erp.fileImport.metrics.rows')}
                      {item.parseResult.delimiter
                        ? ` · ${formatFileImportDelimiter(item.parseResult.delimiter)}`
                        : ''}
                    </p>
                  </div>
                  <StatusPill tone={item.parseResult.ok ? 'success' : 'danger'}>
                    {item.parseResult.ok
                      ? t('erp.readinessStatus.ready')
                      : t('erp.readinessStatus.blocked')}
                  </StatusPill>
                </li>
              ))}
            </ul>

            {staged ? (
              <div className="mt-4 rounded-lg border border-[color-mix(in_srgb,var(--color-success)_25%,transparent)] bg-[var(--color-success-soft)] px-3 py-2 text-sm font-medium text-[var(--color-text-primary)]">
                {t('erp.fileImport.stagedPackage', {
                  count: stagedBatchCount,
                })}
              </div>
            ) : null}

            {packageResult.issues.length > 0 ? (
              <ul className="mt-4 divide-y divide-[var(--color-border)] rounded-lg border border-[var(--color-border)]">
                {packageResult.issues.slice(0, 8).map((issue, index) => (
                  <li key={`${issue.code}-${index}`} className="flex gap-3 p-3">
                    <AlertTriangle
                      className={cn(
                        'mt-0.5 h-4 w-4 shrink-0',
                        issue.level === 'error'
                          ? 'text-[var(--color-danger)]'
                          : 'text-[var(--color-warning)]',
                      )}
                      aria-hidden
                    />
                    <div className="min-w-0">
                      <p className="text-sm font-medium text-[var(--color-text-primary)]">
                        {t(fileImportIssueLabelKey(issue.code), {
                          defaultValue: issue.code,
                        })}
                      </p>
                      {issue.rowNumber || issue.column ? (
                        <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                          {t('erp.fileImport.issueContext', {
                            row: issue.rowNumber ?? '-',
                            column: issue.column ?? '-',
                          })}
                        </p>
                      ) : null}
                    </div>
                  </li>
                ))}
              </ul>
            ) : null}
          </div>
        ) : null}
      </div>
    </SheetShell>
  )
}
