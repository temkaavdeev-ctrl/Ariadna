// Оболочка кэшируется, данные всегда живые.
const C='ariadna-v1';
self.addEventListener('install',e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(['./','index.html','manifest.webmanifest','icon.svg','icon-192.png'])));self.skipWaiting()});
self.addEventListener('activate',e=>e.waitUntil(clients.claim()));
self.addEventListener('fetch',e=>{
  const u=new URL(e.request.url);
  if(u.origin===location.origin){e.respondWith(caches.match(e.request,{ignoreSearch:true}).then(r=>r||fetch(e.request)))}
});
