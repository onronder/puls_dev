import type { StatusTone } from '#/components/puls/StatusPill'

export type PerformanceStatusBand =
  | 'very_good'
  | 'good'
  | 'expected'
  | 'development'
  | 'risk'

export function mapPerformanceStatusBandTone(band: string | null | undefined): StatusTone {
  switch (band) {
    case 'very_good':
      return 'success'
    case 'good':
      return 'info'
    case 'expected':
      return 'neutral'
    case 'development':
      return 'warning'
    case 'risk':
      return 'danger'
    default:
      return 'neutral'
  }
}

export function mapLeaveRequestStatusTone(
  status: string | null | undefined,
): StatusTone {
  switch (status) {
    case 'approved':
      return 'success'
    case 'pending':
      return 'warning'
    case 'rejected':
    case 'cancelled':
      return 'danger'
    default:
      return 'neutral'
  }
}

export function mapExpenseClaimStatusTone(
  status: string | null | undefined,
): StatusTone {
  switch (status) {
    case 'approved':
    case 'paid':
    case 'exported':
      return 'success'
    case 'pending':
      return 'warning'
    case 'rejected':
      return 'danger'
    case 'draft':
    default:
      return 'neutral'
  }
}

export function mapContractStatusTone(status: string | null | undefined): StatusTone {
  switch (status) {
    case 'active':
      return 'success'
    case 'draft':
    case 'pending':
      return 'warning'
    case 'expired':
    case 'terminated':
      return 'danger'
    default:
      return 'neutral'
  }
}

export function mapPerformanceCycleStatus(status: string | null | undefined): string {
  switch (status) {
    case 'draft':
      return 'draft'
    case 'active':
      return 'active'
    case 'closed':
      return 'closed'
    default:
      return 'draft'
  }
}
