import type { CapacitorConfig } from '@capacitor/cli'

/** Native shell loads SSR app from Vercel or local dev (TanStack Start has no static index.html). */
const serverUrl = process.env.CAPACITOR_SERVER_URL

const config: CapacitorConfig = {
  appId: 'io.puls.app',
  appName: 'PULS',
  webDir: '.output/public',
  server: serverUrl
    ? {
        url: serverUrl,
        cleartext: serverUrl.startsWith('http://'),
      }
    : {
        androidScheme: 'https',
      },
  plugins: {
    SplashScreen: {
      launchAutoHide: true,
      backgroundColor: '#090b0a',
    },
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#090b0a',
    },
  },
}

export default config
