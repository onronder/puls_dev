import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'io.puls.app',
  appName: 'PULS',
  webDir: 'dist',
  server: {
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
