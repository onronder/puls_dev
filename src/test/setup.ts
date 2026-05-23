import { beforeEach } from 'vitest'

const memoryStore = new Map<string, string>()

function createMemoryStorage(): Storage {
  return {
    get length() {
      return memoryStore.size
    },
    clear() {
      memoryStore.clear()
    },
    getItem(key: string) {
      return memoryStore.has(key) ? memoryStore.get(key)! : null
    },
    key(index: number) {
      return [...memoryStore.keys()][index] ?? null
    },
    removeItem(key: string) {
      memoryStore.delete(key)
    },
    setItem(key: string, value: string) {
      memoryStore.set(key, value)
    },
  }
}

if (typeof globalThis.localStorage === 'undefined') {
  Object.defineProperty(globalThis, 'localStorage', {
    value: createMemoryStorage(),
    writable: true,
    configurable: true,
  })
}

beforeEach(() => {
  globalThis.localStorage.clear()
})
