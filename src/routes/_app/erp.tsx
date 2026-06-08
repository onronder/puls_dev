import { Navigate, createFileRoute } from '@tanstack/react-router'
import { z } from 'zod'

const legacyErpSearchSchema = z.object({
  tab: z
    .enum(['setup', 'fields', 'check', 'credentials', 'previewApply', 'activity'])
    .optional(),
  focus: z
    .string()
    .regex(/^erp-[a-z0-9-]+$/)
    .optional(),
})

export const Route = createFileRoute('/_app/erp')({
  validateSearch: legacyErpSearchSchema,
  component: LegacyErpRedirect,
})

function LegacyErpRedirect() {
  return <Navigate to="/verikaynaklari" search={Route.useSearch()} replace />
}
