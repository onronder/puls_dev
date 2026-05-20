#!/usr/bin/env node
/**
 * TanStack Start SSR build has no index.html — Capacitor requires one in webDir.
 * Writes a redirect shell; native apps use server.url from capacitor.config.ts.
 */
import { mkdirSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

const outDir = resolve(process.cwd(), '.output/public')
const serverUrl = process.env.CAPACITOR_SERVER_URL ?? 'https://puls-dev.vercel.app'

mkdirSync(outDir, { recursive: true })

const html = `<!DOCTYPE html>
<html lang="tr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
    <title>PULS</title>
    <meta http-equiv="refresh" content="0;url=${serverUrl}" />
    <style>
      body { margin: 0; min-height: 100vh; display: grid; place-items: center;
        background: #090b0a; color: #9aff3e; font-family: system-ui, sans-serif; }
    </style>
  </head>
  <body>
    <p>PULS yükleniyor…</p>
    <script>window.location.replace(${JSON.stringify(serverUrl)})</script>
  </body>
</html>
`

writeFileSync(resolve(outDir, 'index.html'), html, 'utf8')
console.log(`Wrote .output/public/index.html → ${serverUrl}`)
