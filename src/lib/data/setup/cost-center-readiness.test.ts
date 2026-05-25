import { describe, expect, it } from 'vitest'

import {
  computeCostCenterReadinessResult,
  computeCostCenterReadinessStatus,
  type CostCenterReadinessInput,
  type IdentityMapSnapshot,
  type NamespaceSnapshot,
} from '#/lib/data/setup/cost-center-readiness'

const NS_ERP: NamespaceSnapshot = {
  id: 'ns-erp',
  isActive: true,
  sourceType: 'erp',
  name: 'Logo ERP',
  code: 'logo_erp',
}

const NS_EXCEL: NamespaceSnapshot = {
  id: 'ns-excel',
  isActive: true,
  sourceType: 'excel_csv',
  name: 'Excel import',
  code: 'excel_import',
}

const NS_DEMO: NamespaceSnapshot = {
  id: 'ns-demo',
  isActive: true,
  sourceType: 'demo',
  name: 'PULS demo',
  code: 'puls_demo',
}

const NS_MANUAL: NamespaceSnapshot = {
  id: 'ns-manual',
  isActive: true,
  sourceType: 'manual',
  name: 'Manual',
  code: 'manual',
}

const NS_INACTIVE: NamespaceSnapshot = {
  ...NS_ERP,
  isActive: false,
}

function coherentIdentityMap(
  overrides: Partial<IdentityMapSnapshot> = {},
): IdentityMapSnapshot {
  return {
    isActive: true,
    sourceNamespaceId: 'ns-erp',
    externalId: 'EXT-001',
    canonicalId: 'cc-1',
    canonicalSchema: 'puls_core',
    canonicalTable: 'cost_centers',
    entityType: 'cost_center',
    ...overrides,
  }
}

function baseInput(overrides: Partial<CostCenterReadinessInput> = {}): CostCenterReadinessInput {
  return {
    costCenterId: 'cc-1',
    isActive: true,
    sourceNamespaceId: 'ns-erp',
    externalId: 'EXT-001',
    namespace: NS_ERP,
    identityMaps: [coherentIdentityMap()],
    ...overrides,
  }
}

describe('computeCostCenterReadinessStatus', () => {
  it('returns inactive when cost center is inactive even with full coherent ERP mapping', () => {
    const input = baseInput({ isActive: false })
    expect(computeCostCenterReadinessStatus(input)).toBe('inactive')
    expect(computeCostCenterReadinessResult(input).exportSourceType).toBeNull()
  })

  it('returns export_ready for full coherent ERP mapping', () => {
    const result = computeCostCenterReadinessResult(baseInput())
    expect(result.status).toBe('export_ready')
    expect(result.exportSourceType).toBe('erp')
  })

  it('returns export_ready for full coherent excel_csv mapping', () => {
    const input = baseInput({
      sourceNamespaceId: 'ns-excel',
      namespace: NS_EXCEL,
      identityMaps: [
        coherentIdentityMap({
          sourceNamespaceId: 'ns-excel',
          externalId: 'EXT-002',
        }),
      ],
      externalId: 'EXT-002',
    })
    const result = computeCostCenterReadinessResult(input)
    expect(result.status).toBe('export_ready')
    expect(result.exportSourceType).toBe('excel_csv')
  })

  it('returns needs_mapping for coherent demo mapping', () => {
    const input = baseInput({
      sourceNamespaceId: 'ns-demo',
      namespace: NS_DEMO,
      identityMaps: [
        coherentIdentityMap({
          sourceNamespaceId: 'ns-demo',
        }),
      ],
    })
    expect(computeCostCenterReadinessStatus(input)).toBe('needs_mapping')
  })

  it('returns needs_mapping for coherent manual mapping', () => {
    const input = baseInput({
      sourceNamespaceId: 'ns-manual',
      namespace: NS_MANUAL,
      identityMaps: [
        coherentIdentityMap({
          sourceNamespaceId: 'ns-manual',
        }),
      ],
    })
    expect(computeCostCenterReadinessStatus(input)).toBe('needs_mapping')
  })

  it('returns needs_mapping when external_id exists but identity map is missing', () => {
    const input = baseInput({
      identityMaps: [],
    })
    expect(computeCostCenterReadinessStatus(input)).toBe('needs_mapping')
  })

  it('returns needs_mapping when identity map exists but cost center external_id is missing', () => {
    const input = baseInput({
      externalId: null,
    })
    expect(computeCostCenterReadinessStatus(input)).toBe('needs_mapping')
  })

  it('returns needs_mapping when identity map external_id mismatches', () => {
    const input = baseInput({
      identityMaps: [
        coherentIdentityMap({
          externalId: 'EXT-MISMATCH',
        }),
      ],
    })
    expect(computeCostCenterReadinessStatus(input)).toBe('needs_mapping')
  })

  it('returns needs_mapping when source_namespace_id mismatches', () => {
    const input = baseInput({
      sourceNamespaceId: 'ns-other',
      identityMaps: [
        coherentIdentityMap({
          sourceNamespaceId: 'ns-erp',
        }),
      ],
    })
    expect(computeCostCenterReadinessStatus(input)).toBe('needs_mapping')
  })

  it('returns needs_mapping when namespace is inactive', () => {
    const input = baseInput({
      namespace: NS_INACTIVE,
    })
    expect(computeCostCenterReadinessStatus(input)).toBe('needs_mapping')
  })

  it('returns puls_only when there are no mapping signals', () => {
    const input = baseInput({
      sourceNamespaceId: null,
      externalId: null,
      namespace: null,
      identityMaps: [],
    })
    expect(computeCostCenterReadinessStatus(input)).toBe('puls_only')
  })

  it('returns needs_mapping for partial signal with namespace only and no external_id', () => {
    const input = baseInput({
      externalId: null,
      identityMaps: [],
    })
    expect(computeCostCenterReadinessStatus(input)).toBe('needs_mapping')
  })

  it('returns inactive for inactive cost center with full mapping signals', () => {
    const input = baseInput({ isActive: false })
    expect(computeCostCenterReadinessStatus(input)).toBe('inactive')
  })
})
