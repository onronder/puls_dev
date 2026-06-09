import { beforeEach, describe, expect, it, vi } from 'vitest'

import { logPersonaSwitch } from '#/lib/persona'

const supabaseMock = vi.hoisted(() => {
  const insert = vi.fn()
  const schemaFrom = vi.fn(() => ({ insert }))
  const schema = vi.fn(() => ({ from: schemaFrom }))
  const from = vi.fn(() => ({ insert }))
  return { insert, schemaFrom, schema, from }
})

vi.mock('#/lib/supabase', () => ({
  supabase: {
    schema: supabaseMock.schema,
    from: supabaseMock.from,
  },
}))

describe('logPersonaSwitch', () => {
  beforeEach(() => {
    supabaseMock.insert.mockReset()
    supabaseMock.schemaFrom.mockClear()
    supabaseMock.schema.mockClear()
    supabaseMock.from.mockClear()
  })

  it('writes persona switches only to puls_audit.audit_logs', async () => {
    supabaseMock.insert.mockResolvedValue({ error: null })

    await logPersonaSwitch({
      userId: 'user-1',
      tenantId: 'tenant-1',
      persona: 'manager',
    })

    expect(supabaseMock.schema).toHaveBeenCalledWith('puls_audit')
    expect(supabaseMock.schemaFrom).toHaveBeenCalledWith('audit_logs')
    expect(supabaseMock.insert).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-1',
        actor_id: 'user-1',
        action: 'persona_switch',
      }),
    )
    expect(supabaseMock.from).not.toHaveBeenCalled()
  })

  it('does not fall back to legacy audit schemas when puls_audit rejects the write', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined)
    supabaseMock.insert.mockResolvedValue({ error: { message: 'rls denied' } })

    await logPersonaSwitch({
      userId: 'user-1',
      tenantId: 'tenant-1',
      persona: 'employee',
    })

    expect(supabaseMock.schema).toHaveBeenCalledTimes(1)
    expect(supabaseMock.from).not.toHaveBeenCalled()
    expect(warn).toHaveBeenCalledWith(
      'Persona switch audit failed on puls_audit.audit_logs.',
      expect.objectContaining({ message: 'rls denied' }),
    )

    warn.mockRestore()
  })

  it('skips the audit write when tenant context is missing', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined)

    await logPersonaSwitch({
      userId: 'user-1',
      tenantId: null,
      persona: 'manager',
    })

    expect(supabaseMock.schema).not.toHaveBeenCalled()
    expect(supabaseMock.from).not.toHaveBeenCalled()
    expect(warn).toHaveBeenCalledWith('Persona switch audit skipped: tenant context is missing.')

    warn.mockRestore()
  })
})
