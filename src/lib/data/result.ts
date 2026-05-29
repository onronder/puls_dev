import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import { DataAdapterError } from '#/lib/data/errors'

export type DataResult<T> = {
  source: 'real' | 'demo'
  status: 'success' | 'empty' | 'error'
  data: T
  error?: DataAdapterError
  fallbackReason?: 'empty' | 'error'
}

export type ResolveAdapterDataOptions<T> = {
  operation: string
  fetchReal: () => Promise<T>
  fetchDemo: () => Promise<T>
  isEmpty?: (data: T) => boolean
}

export async function resolveAdapterData<T>({
  operation,
  fetchReal,
  fetchDemo,
  isEmpty,
}: ResolveAdapterDataOptions<T>): Promise<T> {
  const result = await resolveAdapterDataWithMeta({ operation, fetchReal, fetchDemo, isEmpty })
  if (result.status === 'error' && result.error) {
    throw result.error
  }
  return result.data
}

export async function resolveAdapterDataWithMeta<T>({
  operation,
  fetchReal,
  fetchDemo,
  isEmpty,
}: ResolveAdapterDataOptions<T>): Promise<DataResult<T>> {
  const demoEnabled = isPulsDemoModeEnabled()

  try {
    const data = await fetchReal()
    const empty = isEmpty ? isEmpty(data) : false

    if (!empty) {
      return { source: 'real', status: 'success', data }
    }

    if (demoEnabled) {
      const demoData = await fetchDemo()
      return { source: 'demo', status: 'success', data: demoData, fallbackReason: 'empty' }
    }

    return { source: 'real', status: 'empty', data }
  } catch (error) {
    if (demoEnabled) {
      try {
        const demoData = await fetchDemo()
        return { source: 'demo', status: 'success', data: demoData, fallbackReason: 'error' }
      } catch {
        // fall through to normalized error
      }
    }

    const normalized =
      error instanceof DataAdapterError
        ? error
        : new DataAdapterError({
            code: 'unknown',
            message: error instanceof Error ? error.message : 'Unknown error',
            source: 'adapter',
            operation,
          })

    return { source: 'real', status: 'error', data: undefined as T, error: normalized }
  }
}
