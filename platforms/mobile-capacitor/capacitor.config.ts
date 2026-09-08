import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'app.codavybes.social',
  appName: 'CodaVybes',
  webDir: '../../dist',
  server: {
    androidScheme: 'https',
  },
  plugins: {
    StatusBar: {
      overlaysWebView: false,
    },
    Keyboard: {
      resize: 'body',
    },
    LocalNotifications: {
      iconColor: '#FF7A1C',
    },
  },
}

export default config
