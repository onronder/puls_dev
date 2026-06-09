import { TabsContent } from '#/components/ui/tabs'

import { ControlledApplySection } from './DataSourceControlledApplySection'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'
import {
  ApplyChangeSetSection,
  ApplyReadinessSection,
  ImportPreviewSection,
} from './DataSourcePreviewApplyImportSections'
import {
  GuardedUpdateEvidenceSection,
  GuardedUpdateRecoveryRunbookSection,
  GuardedUpdateRecoverySection,
} from './DataSourcePreviewApplyRecoverySections'
import {
  GuardedUpdateRollbackPreviewSection,
  GuardedUpdateRollbackWorkerApplySection,
  GuardedUpdateRollbackWorkerReadinessSection,
} from './DataSourcePreviewApplyRollbackSections'

export function DataSourcePreviewApplyTabPanel(props: DataSourceTechnicalTabPanelProps) {
  return (
    <TabsContent value="previewApply" className="mt-6">
      <ImportPreviewSection {...props} />
      <ApplyReadinessSection {...props} />
      <ApplyChangeSetSection {...props} />
      <GuardedUpdateEvidenceSection {...props} />
      <GuardedUpdateRecoverySection {...props} />
      <GuardedUpdateRecoveryRunbookSection {...props} />
      <GuardedUpdateRollbackPreviewSection {...props} />
      <GuardedUpdateRollbackWorkerReadinessSection {...props} />
      <GuardedUpdateRollbackWorkerApplySection {...props} />
      <ControlledApplySection {...props} />
    </TabsContent>
  )
}
