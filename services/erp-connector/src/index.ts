import { createServer } from 'node:http'

const port = Number(process.env.PORT ?? 8081)

createServer((_req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' })
  res.end(
    JSON.stringify({
      service: 'erp-connector-canias',
      status: 'ok',
      provider: 'canias',
      version: '0.1.0-skeleton',
    }),
  )
}).listen(port, () => {
  console.log(`erp-connector skeleton listening on :${port}`)
})
