import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'

import trTR from '#/i18n/locales/tr-TR.json'
import enUS from '#/i18n/locales/en-US.json'

void i18n.use(initReactI18next).init({
  resources: {
    'tr-TR': { translation: trTR },
    'en-US': { translation: enUS },
  },
  lng: 'tr-TR',
  fallbackLng: 'tr-TR',
  interpolation: { escapeValue: false },
})

export default i18n
