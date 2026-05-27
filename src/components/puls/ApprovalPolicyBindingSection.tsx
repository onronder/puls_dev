import { useTranslation } from 'react-i18next'

import { StatusPill } from '#/components/puls/StatusPill'
import type { StatusTone } from '#/components/puls/StatusPill'
import type {
  ApprovalPolicyBindingInfo,
  ApprovalPolicyBindingStatus,
} from '#/lib/data/workflow/policy-binding-readiness'

function bindingStatusTone(status: ApprovalPolicyBindingStatus): StatusTone {
  return status === 'ready' ? 'success' : 'warning'
}

type ApprovalPolicyBindingSectionProps = {
  binding: ApprovalPolicyBindingInfo
}

export function ApprovalPolicyBindingSection({ binding }: ApprovalPolicyBindingSectionProps) {
  const { t } = useTranslation()

  const policyLabel =
    binding.policyName?.trim() ||
    (binding.status === 'unbound' ? t('approvalPolicyBinding.empty') : '—')

  return (
    <section className="space-y-2 pt-2">
      <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
        {t('approvalPolicyBinding.title')}
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <StatusPill tone={bindingStatusTone(binding.status)}>
          {t(`approvalPolicyBinding.status.${binding.status}`)}
        </StatusPill>
        <span className="text-sm font-medium text-[var(--color-text-primary)]">{policyLabel}</span>
      </div>
      <p className="text-sm text-[var(--color-text-secondary)]">
        {t(`approvalPolicyBinding.description.${binding.status}`)}
      </p>
    </section>
  )
}
