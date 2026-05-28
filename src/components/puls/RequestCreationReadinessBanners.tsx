import { AlertTriangle } from 'lucide-react'
import type { TFunction } from 'i18next'

import {
  getPrimaryRequestCreationBlocker,
  getRequestCreationBlockerI18nKey,
  getRequestCreationWarningI18nKey,
  type RequestCreationReadiness,
} from '#/lib/data'

type RequestCreationReadinessBannersProps = {
  readiness: RequestCreationReadiness
  t: TFunction
}

export function RequestCreationReadinessBanners({
  readiness,
  t,
}: RequestCreationReadinessBannersProps) {
  const primaryBlocker = getPrimaryRequestCreationBlocker(readiness)

  return (
    <>
      {primaryBlocker ? (
        <div className="flex items-start gap-2 rounded-md border border-danger/30 bg-danger-soft p-3 text-[13px] text-danger">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <div>
            <div className="font-medium">{t('requestCreationReadiness.common.blockingTitle')}</div>
            <div className="mt-0.5 text-[12px]">
              {t(getRequestCreationBlockerI18nKey(primaryBlocker, readiness.domain))}
            </div>
          </div>
        </div>
      ) : null}
      {readiness.warnings.length > 0 ? (
        <div className="flex items-start gap-2 rounded-md border border-warning/30 bg-warning-soft p-3 text-[13px] text-warning">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <div>
            <div className="font-medium">{t('requestCreationReadiness.common.warningTitle')}</div>
            <ul className="mt-1 list-disc space-y-0.5 pl-4 text-[12px]">
              {readiness.warnings.map((warning) => (
                <li key={warning}>{t(getRequestCreationWarningI18nKey(warning))}</li>
              ))}
            </ul>
          </div>
        </div>
      ) : null}
    </>
  )
}
