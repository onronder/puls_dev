import { createServer } from 'node:http'

const port = Number(process.env.PORT ?? 8080)

createServer((_req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' })
  res.end(
    JSON.stringify({
      service: 'llm-gateway',
      status: 'ok',
      version: '0.1.0-skeleton',
    }),
  )
}).listen(port, () => {
  console.log(`llm-gateway skeleton listening on :${port}`)
})
