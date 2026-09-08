import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'app.vybe.social',
  appName: 'VYBE',
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
      iconColor: '#665CFF',
    },
  },
}

export default config
