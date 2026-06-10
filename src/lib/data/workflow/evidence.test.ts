import { beforeEach, describe, expect, it, vi } from 'vitest'

import {
  createWorkflowEvidenceSignedUrl,
  getWorkflowEvidenceFilePolicy,
  groupWorkflowEvidenceByParent,
  mapWorkflowEvidenceAttachmentRow,
  validateWorkflowEvidenceFile,
} from '#/lib/data/workflow/evidence'
import { supabase } from '#/lib/supabase'

vi.mock('#/lib/supabase', () => ({
  supabase: {
    storage: {
      from: vi.fn(),
    },
  },
}))

function file(name: string, type: string, size: number): File {
  return { name, type, size } as File
}

describe('workflow evidence file policy', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('allows PDF and images for leave and expense evidence', () => {
    expect(
      validateWorkflowEvidenceFile('leave', file('rapor.pdf', 'application/pdf', 128)),
    ).toBeNull()
    expect(validateWorkflowEvidenceFile('expense', file('fis.jpg', 'image/jpeg', 128))).toBeNull()
    expect(validateWorkflowEvidenceFile('expense', file('fis.png', 'image/png', 128))).toBeNull()
  })

  it('keeps contract evidence PDF-only', () => {
    expect(
      validateWorkflowEvidenceFile('contract', file('sozlesme.pdf', 'application/pdf', 128)),
    ).toBeNull()
    expect(validateWorkflowEvidenceFile('contract', file('sozlesme.png', 'image/png', 128))).toBe(
      'type',
    )
  })

  it('rejects empty and oversized files before upload intent creation', () => {
    const policy = getWorkflowEvidenceFilePolicy('leave')

    expect(validateWorkflowEvidenceFile('leave', file('bos.pdf', 'application/pdf', 0))).toBe(
      'size',
    )
    expect(
      validateWorkflowEvidenceFile(
        'leave',
        file('buyuk.pdf', 'application/pdf', policy.maxBytes + 1),
      ),
    ).toBe('size')
  })
})

describe('workflow evidence viewing helpers', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('maps attached domain rows without changing the storage path', () => {
    expect(
      mapWorkflowEvidenceAttachmentRow('expense', {
        id: 'receipt-1',
        expense_claim_id: 'claim-1',
        uploaded_by_employee_id: 'employee-1',
        file_ref: 'tenant-1/expense/upload/evidence.pdf',
        file_name: 'fis.pdf',
        mime_type: 'application/pdf',
        file_size_bytes: 1200,
        created_at: '2026-06-10T10:00:00Z',
      }),
    ).toEqual({
      id: 'receipt-1',
      domain: 'expense',
      parentId: 'claim-1',
      storageBucket: 'workflow-evidence',
      storagePath: 'tenant-1/expense/upload/evidence.pdf',
      fileName: 'fis.pdf',
      mimeType: 'application/pdf',
      fileSizeBytes: 1200,
      uploadedByEmployeeId: 'employee-1',
      attachedAt: '2026-06-10T10:00:00Z',
      scanStatus: 'not_scanned',
    })
  })

  it('groups evidence by parent record for overview rows', () => {
    const first = mapWorkflowEvidenceAttachmentRow('leave', {
      id: 'document-1',
      leave_request_id: 'leave-1',
      file_ref: 'tenant-1/leave/1/evidence.pdf',
      file_name: 'rapor.pdf',
    })
    const second = mapWorkflowEvidenceAttachmentRow('leave', {
      id: 'document-2',
      leave_request_id: 'leave-1',
      file_ref: 'tenant-1/leave/2/evidence.pdf',
      file_name: 'rapor-2.pdf',
    })

    const grouped = groupWorkflowEvidenceByParent([first, second])

    expect(grouped.get('leave-1')).toEqual([first, second])
  })

  it('creates short-lived signed URLs through the private storage bucket', async () => {
    const createSignedUrl = vi.fn(async () => ({
      data: { signedUrl: 'https://signed.example/evidence' },
      error: null,
    }))
    vi.mocked(supabase.storage.from).mockReturnValue({ createSignedUrl } as never)

    await expect(
      createWorkflowEvidenceSignedUrl({
        id: 'receipt-1',
        domain: 'expense',
        parentId: 'claim-1',
        storageBucket: 'workflow-evidence',
        storagePath: 'tenant-1/expense/upload/evidence.pdf',
        fileName: 'fis.pdf',
        mimeType: 'application/pdf',
        fileSizeBytes: 1200,
        uploadedByEmployeeId: 'employee-1',
        attachedAt: '2026-06-10T10:00:00Z',
        scanStatus: 'not_scanned',
      }),
    ).resolves.toBe('https://signed.example/evidence')

    expect(supabase.storage.from).toHaveBeenCalledWith('workflow-evidence')
    expect(createSignedUrl).toHaveBeenCalledWith('tenant-1/expense/upload/evidence.pdf', 120)
  })
})
