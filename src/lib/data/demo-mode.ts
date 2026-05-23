const TRUTHY = new Set(['true', '1', 'yes'])

export function isPulsDemoModeEnabled(): boolean {
  const raw = import.meta.env.VITE_PULS_DEMO_MODE
  if (raw == null || raw === '') return false
  return TRUTHY.has(String(raw).trim().toLowerCase())
}
