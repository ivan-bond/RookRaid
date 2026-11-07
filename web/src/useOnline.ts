import { useSyncExternalStore } from 'react'

/** Browser network state (NetworkMonitor in the app). Battle needs a connection, like on the iPhone. */
export function useOnline(): boolean {
  return useSyncExternalStore(fn => {
    window.addEventListener('online', fn)
    window.addEventListener('offline', fn)
    return () => { window.removeEventListener('online', fn); window.removeEventListener('offline', fn) }
  }, () => navigator.onLine)
}
