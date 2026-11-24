/* TRANSFORMATION — service worker μόνο για ειδοποιήσεις (π.χ. «Τέλος διαλείμματος»).
   Δεν αποθηκεύει τίποτα στη μνήμη (cache): η εφαρμογή φορτώνει πάντα την τελευταία έκδοση. */
self.addEventListener('install', ()=>self.skipWaiting());
self.addEventListener('activate', e=>e.waitUntil(self.clients.claim()));

self.addEventListener('push', e=>{
  let d = {};
  try{ d = e.data ? e.data.json() : {}; }catch(_){ d = { body: e.data ? e.data.text() : '' }; }
  const title = d.title || 'TRANSFORMATION';
  e.waitUntil(self.registration.showNotification(title, {
    body: d.body || '',
    tag: d.tag || 'rest',
    renotify: true,
    icon: 'icons/icon-192.png?v=6',
    badge: 'icons/favicon-64.png?v=6',
    vibrate: [300, 150, 300, 150, 300],
    data: { url: d.url || './' }
  }));
});

self.addEventListener('notificationclick', e=>{
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || './';
  e.waitUntil((async ()=>{
    const all = await self.clients.matchAll({ type:'window', includeUncontrolled:true });
    for(const c of all){ if('focus' in c){ try{ await c.focus(); return; }catch(_){} } }
    if(self.clients.openWindow) await self.clients.openWindow(url);
  })());
});
