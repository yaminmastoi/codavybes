import { createContext, useContext, useEffect, useMemo, useState } from 'react'

const ThemeContext = createContext(null)
const STORAGE_KEY = 'vybe-theme'

function resolveTheme(preference) {
  if (preference === 'system') {
    return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  }
  return preference === 'dark' ? 'dark' : 'light'
}

export function ThemeProvider({ children }) {
  const [preference, setPreferenceState] = useState(() => localStorage.getItem(STORAGE_KEY) || 'light')
  const [resolvedTheme, setResolvedTheme] = useState(() => resolveTheme(localStorage.getItem(STORAGE_KEY) || 'light'))

  useEffect(() => {
    const media = window.matchMedia?.('(prefers-color-scheme: dark)')
    const apply = () => {
      const next = resolveTheme(preference)
      setResolvedTheme(next)
      document.documentElement.dataset.theme = next
      document.documentElement.style.colorScheme = next
      document.querySelector('meta[name=\"theme-color\"]')?.setAttribute('content', next === 'dark' ? '#0b0d12' : '#f6f7fa')
    }
    apply()
    if (preference === 'system') media?.addEventListener?.('change', apply)
    return () => media?.removeEventListener?.('change', apply)
  }, [preference])

  const setTheme = (next) => {
    const safe = ['light', 'dark', 'system'].includes(next) ? next : 'light'
    localStorage.setItem(STORAGE_KEY, safe)
    setPreferenceState(safe)
  }

  const value = useMemo(() => ({ preference, resolvedTheme, setTheme }), [preference, resolvedTheme])
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export function useTheme() {
  const value = useContext(ThemeContext)
  if (!value) throw new Error('useTheme must be used inside ThemeProvider')
  return value
}
