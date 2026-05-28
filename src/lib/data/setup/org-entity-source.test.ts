import { describe, expect, it } from 'vitest'

import { mapOrgEntitySource } from '#/lib/data/setup/org-entity-source'

describe('mapOrgEntitySource', () => {
  it('defaults to puls when external_source is missing', () => {
    expect(mapOrgEntitySource(null)).toBe('puls')
    expect(mapOrgEntitySource(undefined)).toBe('puls')
    expect(mapOrgEntitySource('')).toBe('puls')
    expect(mapOrgEntitySource('   ')).toBe('puls')
  })

  it('maps ERP-like sources conservatively', () => {
    expect(mapOrgEntitySource('erp')).toBe('erp')
    expect(mapOrgEntitySource('Canias')).toBe('erp')
    expect(mapOrgEntitySource('SAP_IMPORT')).toBe('erp')
  })

  it('maps explicit demo source', () => {
    expect(mapOrgEntitySource('demo')).toBe('demo')
  })

  it('returns unknown for ambiguous external sources', () => {
    expect(mapOrgEntitySource('manual_entry')).toBe('unknown')
    expect(mapOrgEntitySource('legacy_sync')).toBe('unknown')
  })
})
