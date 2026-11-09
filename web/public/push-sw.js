// Push handling, imported into the generated service worker (vite.config.ts → workbox.importScripts).
// push-dispatch sends { title, body, url, tag }; a tap opens Rook Raid on the friends list.
self.addEventListener('push', (event) => {
  let data = {}
  try { data = event.data ? event.data.json() : {} } catch { data = { body: event.data ? event.data.text() : '' } }
  event.waitUntil(self.registration.showNotification(data.title || 'Rook Raid', {
    body: data.body || '',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: data.tag || 'rookraid',
    data: { url: data.url || '/' },
  }))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = new URL((event.notification.data && event.notification.data.url) || '/', self.location.origin).href
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const client of list) {
      if (new URL(client.url).origin === self.location.origin && 'focus' in client) {
        client.postMessage({ type: 'rookraid-open', url })
        return client.focus()
      }
    }
    return self.clients.openWindow(url)
  }))
})
