import { createServer } from 'node:http'
import { pathToFileURL } from 'node:url'

import {
  buildHealthPayload,
  resolveWorkerConfig,
  startConnectorWorkerLoop,
} from './worker.ts'

const config = resolveWorkerConfig()

export const server = createServer((_req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' })
  res.end(JSON.stringify(buildHealthPayload(config)))
})

export function startService() {
  const stopWorker =
    config.enabled && config.configured ? startConnectorWorkerLoop(config) : () => undefined

  server.listen(config.port, () => {
    const workerMode =
      config.enabled && config.configured ? 'worker loop enabled' : 'worker loop disabled'
    console.log(`erp-connector ${workerMode} listening on :${config.port}`)
  })

  return () => {
    stopWorker()
    server.close()
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  startService()
}
