import { describe, expect, it } from 'vitest'

import {
  connectorJourneyStepFromTarget,
  dataSourceDisplayName,
  formatDataSourceScope,
  readinessTone,
  type DataSourceSummary,
} from './dataSourceUi'

const translate = (key: string, options?: Record<string, unknown>) =>
  typeof options?.defaultValue === 'string' ? options.defaultValue : key

function buildSource(overrides: Partial<DataSourceSummary>): DataSourceSummary {
  return {
    id: 'source-1',
    providerId: 'csv_import',
    providerLabelKey: 'erp.providerOptions.csv_import.label',
    displayName: 'CSV / Excel Import',
    typeLabelKey: 'erp.providerCatalog.categories.file',
    methodLabelKey: 'erp.transferMethods.file',
    sourceKind: 'connection',
    connectionId: 'connection-1',
    active: true,
    status: 'ready',
    readiness: 'ready',
    setupAvailable: true,
    scope: ['employees'],
    lastRunAt: null,
    nextAction: 'upload_file',
    nextActionLabelKey: 'erp.dataSources.nextActions.uploadFile',
    primaryAction: 'upload_file',
    canEdit: true,
    canPause: true,
    canRunPreview: false,
    canUploadFile: true,
    ...overrides,
  } as DataSourceSummary
}

describe('dataSourceUi', () => {
  it('maps technical focus targets to the product journey step', () => {
    expect(connectorJourneyStepFromTarget('activity', 'erp-runtime-queue')).toBe('activity')
    expect(connectorJourneyStepFromTarget('previewApply', 'erp-apply-change-set')).toBe('review')
    expect(connectorJourneyStepFromTarget('previewApply', 'erp-import-preview')).toBe('preview')
    expect(connectorJourneyStepFromTarget('credentials', 'erp-credential-boundary')).toBe('source')
  })

  it('uses provider translation when a source display name is empty', () => {
    const source = buildSource({ displayName: '   ', providerLabelKey: 'provider.csv' })

    expect(dataSourceDisplayName(source, translate)).toBe('provider.csv')
  })

  it('formats data source scope with translated values and empty fallback', () => {
    expect(
      formatDataSourceScope(buildSource({ scope: ['employees', 'departments'] }), translate),
    ).toBe('employees, departments')
    expect(formatDataSourceScope(buildSource({ scope: [] }), translate)).toBe(
      'erp.dataSources.values.noScope',
    )
  })

  it('keeps readiness tones aligned with status semantics', () => {
    expect(readinessTone('ready')).toBe('success')
    expect(readinessTone('partial')).toBe('warning')
    expect(readinessTone('blocked')).toBe('neutral')
  })
})
