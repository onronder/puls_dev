import { describe, expect, it } from 'vitest'

import {
  getWorkflowEvidenceFilePolicy,
  validateWorkflowEvidenceFile,
} from '#/lib/data/workflow/evidence'

function file(name: string, type: string, size: number): File {
  return { name, type, size } as File
}

describe('workflow evidence file policy', () => {
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
