import { useTranslation } from 'react-i18next'

import { SheetShell } from '#/components/puls/SheetShell'
import { Tabs, TabsList, TabsTrigger } from '#/components/ui/tabs'

import { DataSourceActivityTabPanel } from './DataSourceActivityTabPanel'
import { DataSourceCheckTabPanel } from './DataSourceCheckTabPanel'
import { DataSourceCredentialsTabPanel } from './DataSourceCredentialsTabPanel'
import { DataSourceFieldsTabPanel } from './DataSourceFieldsTabPanel'
import { DataSourcePreviewApplyTabPanel } from './DataSourcePreviewApplyTabPanel'
import { DataSourceSetupTabPanel } from './DataSourceSetupTabPanel'
import type { DataSourceTechnicalDetailsSheetProps } from './DataSourceTechnicalDetailsTypes'
import { ERP_WORKBENCH_TABS, type ErpWorkbenchTab } from './dataSourceUi'

export function DataSourceTechnicalDetailsSheet({
  data,
  technicalDetailsOpen,
  setTechnicalDetailsOpen,
  activeWorkbenchTab,
  setActiveWorkbenchTab,
  showWorkbenchTab,
  credentialSheetOpen,
  setCredentialSheetOpen,
  permissions,
  mutations,
}: DataSourceTechnicalDetailsSheetProps) {
  const { t } = useTranslation()

  return (
    <SheetShell
      open={technicalDetailsOpen}
      onOpenChange={setTechnicalDetailsOpen}
      title={t('erp.journey.technicalDetails.title')}
      description={t('erp.journey.technicalDetails.description')}
      className="w-[calc(100vw-1rem)] sm:inset-x-auto sm:bottom-4 sm:left-auto sm:right-4 sm:top-4 sm:mt-0 sm:h-auto sm:max-h-none sm:w-[min(1040px,calc(100vw-2rem))] sm:rounded-2xl"
    >
      <Tabs
        value={activeWorkbenchTab}
        onValueChange={(value) => setActiveWorkbenchTab(value as ErpWorkbenchTab)}
        className="space-y-4"
      >
        <div className="-mx-4 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0">
          <TabsList
            aria-label={t('erp.tabs.label')}
            className="h-auto w-max min-w-full gap-1 rounded-xl p-1 sm:w-full"
          >
            {ERP_WORKBENCH_TABS.map((tab) => (
              <TabsTrigger
                key={tab}
                value={tab}
                className="min-w-[132px] flex-none whitespace-nowrap px-3 py-2 sm:min-w-0 sm:flex-1"
              >
                {t(`erp.tabs.${tab}`)}
              </TabsTrigger>
            ))}
          </TabsList>
        </div>

        <DataSourceSetupTabPanel
          data={data}
          permissions={permissions}
          mutations={mutations}
          showWorkbenchTab={showWorkbenchTab}
        />
        <DataSourceCheckTabPanel data={data} />
        <DataSourcePreviewApplyTabPanel
          data={data}
          permissions={permissions}
          mutations={mutations}
        />
        <DataSourceCredentialsTabPanel
          data={data}
          permissions={permissions}
          mutations={mutations}
          credentialSheetOpen={credentialSheetOpen}
          setCredentialSheetOpen={setCredentialSheetOpen}
        />
        <DataSourceFieldsTabPanel data={data} />
        <DataSourceActivityTabPanel data={data} permissions={permissions} mutations={mutations} />
      </Tabs>
    </SheetShell>
  )
}
