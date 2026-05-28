export type OrgSetupEntitySource = 'puls' | 'erp' | 'demo' | 'unknown'

export function mapOrgEntitySource(externalSource: string | null | undefined): OrgSetupEntitySource {
  const normalized = externalSource?.trim().toLowerCase()
  if (!normalized) return 'puls'
  if (normalized.includes('erp') || normalized.includes('canias') || normalized.includes('sap')) {
    return 'erp'
  }
  if (normalized === 'demo') return 'demo'
  return 'unknown'
}
