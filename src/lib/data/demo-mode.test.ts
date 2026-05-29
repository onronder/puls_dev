import { afterEach, describe, expect, it } from 'vitest'

import { isPulsDemoModeEnabled, readPulsDemoModeConfig } from '#/lib/data/demo-mode'

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

describe('readPulsDemoModeConfig', () => {
  it('returns disabled when demo flag is missing', () => {
    expect(readPulsDemoModeConfig({})).toEqual({
      requested: false,
      enabled: false,
      productionBuild: false,
      allowInProduction: false,
      blockedReason: null,
    })
  })

  it('enables demo in non-production when requested', () => {
    expect(
      readPulsDemoModeConfig({
        VITE_PULS_DEMO_MODE: 'true',
        PROD: false,
      }),
    ).toEqual({
      requested: true,
      enabled: true,
      productionBuild: false,
      allowInProduction: false,
      blockedReason: null,
    })
  })

  it('blocks demo in production build unless override is set', () => {
    expect(
      readPulsDemoModeConfig({
        VITE_PULS_DEMO_MODE: 'true',
        PROD: true,
      }),
    ).toEqual({
      requested: true,
      enabled: false,
      productionBuild: true,
      allowInProduction: false,
      blockedReason: 'production_build',
    })
  })

  it('does not treat string PROD as production build', () => {
    expect(
      readPulsDemoModeConfig({
        VITE_PULS_DEMO_MODE: 'true',
        PROD: 'true' as unknown as boolean,
      }),
    ).toEqual({
      requested: true,
      enabled: true,
      productionBuild: false,
      allowInProduction: false,
      blockedReason: null,
    })
  })

  it('allows demo in production when override is truthy', () => {
    expect(
      readPulsDemoModeConfig({
        VITE_PULS_DEMO_MODE: 'yes',
        PROD: true,
        VITE_PULS_ALLOW_DEMO_FALLBACK_IN_PROD: '1',
      }),
    ).toEqual({
      requested: true,
      enabled: true,
      productionBuild: true,
      allowInProduction: true,
      blockedReason: null,
    })
  })
})
