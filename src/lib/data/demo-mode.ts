const TRUTHY = new Set(['true', '1', 'yes'])

export type PulsDemoModeConfig = {
  requested: boolean
  enabled: boolean
  productionBuild: boolean
  allowInProduction: boolean
  blockedReason: 'production_build' | null
}

type DemoModeEnv = {
  PROD?: boolean
  VITE_PULS_DEMO_MODE?: string
  VITE_PULS_ALLOW_DEMO_FALLBACK_IN_PROD?: string
}

function isTruthyEnvValue(raw: string | undefined | null): boolean {
  if (raw == null || raw === '') return false
  return TRUTHY.has(String(raw).trim().toLowerCase())
}

export function readPulsDemoModeConfig(env: DemoModeEnv = import.meta.env): PulsDemoModeConfig {
  const requested = isTruthyEnvValue(env.VITE_PULS_DEMO_MODE)
  const productionBuild = env.PROD === true
  const allowInProduction = isTruthyEnvValue(env.VITE_PULS_ALLOW_DEMO_FALLBACK_IN_PROD)
  const enabled = requested && (!productionBuild || allowInProduction)
  const blockedReason =
    requested && productionBuild && !allowInProduction ? 'production_build' : null

  return {
    requested,
    enabled,
    productionBuild,
    allowInProduction,
    blockedReason,
  }
}

export function isPulsDemoModeEnabled(): boolean {
  return readPulsDemoModeConfig().enabled
}
