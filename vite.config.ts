import { defineConfig } from 'vite'
import { devtools } from '@tanstack/devtools-vite'
import { sentryVitePlugin } from '@sentry/vite-plugin'

import { tanstackStart } from '@tanstack/react-start/plugin/vite'

import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { nitro } from 'nitro/vite'

const sentrySourceMapsEnabled =
  process.env.SENTRY_SOURCE_MAPS === 'true' &&
  Boolean(process.env.SENTRY_AUTH_TOKEN && process.env.SENTRY_ORG && process.env.SENTRY_PROJECT)

const sentryRelease =
  process.env.VITE_SENTRY_RELEASE || process.env.SENTRY_RELEASE || process.env.VERCEL_GIT_COMMIT_SHA

const config = defineConfig({
  resolve: { tsconfigPaths: true },
  build: {
    sourcemap: sentrySourceMapsEnabled,
  },
  define: sentryRelease
    ? {
        'import.meta.env.VITE_SENTRY_RELEASE': JSON.stringify(sentryRelease),
      }
    : undefined,
  plugins: [
    devtools(),
    nitro(),
    tailwindcss(),
    tanstackStart(),
    viteReact(),
    sentrySourceMapsEnabled
      ? sentryVitePlugin({
          org: process.env.SENTRY_ORG,
          project: process.env.SENTRY_PROJECT,
          authToken: process.env.SENTRY_AUTH_TOKEN,
          telemetry: false,
          release: {
            name: sentryRelease,
            inject: true,
            create: true,
            finalize: true,
            setCommits: {
              auto: true,
              ignoreEmpty: true,
              ignoreMissing: true,
            },
          },
          sourcemaps: {
            assets: './.output/public/assets/**',
            filesToDeleteAfterUpload: './.output/public/assets/**/*.map',
          },
        })
      : null,
  ],
})

export default config
