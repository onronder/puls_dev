import { afterEach, describe, expect, it } from 'vitest'

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'

describe('isPulsDemoModeEnabled', () => {
  const original = import.meta.env.VITE_PULS_DEMO_MODE

  afterEach(() => {
    import.meta.env.VITE_PULS_DEMO_MODE = original
  })

  it('returns false when unset', () => {
    import.meta.env.VITE_PULS_DEMO_MODE = undefined
    expect(isPulsDemoModeEnabled()).toBe(false)
  })

  it('returns false when empty string', () => {
    import.meta.env.VITE_PULS_DEMO_MODE = ''
    expect(isPulsDemoModeEnabled()).toBe(false)
  })

  it('returns false for false', () => {
    import.meta.env.VITE_PULS_DEMO_MODE = 'false'
    expect(isPulsDemoModeEnabled()).toBe(false)
  })

  it.each(['true', '1', 'yes', 'TRUE', ' Yes '])('returns true for %s', (value) => {
    import.meta.env.VITE_PULS_DEMO_MODE = value
    expect(isPulsDemoModeEnabled()).toBe(true)
  })
})
