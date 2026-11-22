// Κατεβάζει ΟΛΑ τα αρχεία από το Supabase Storage (όλα τα buckets) στον φάκελο που δίνεται.
// Τυπώνει ΜΟΝΟ πλήθη/μεγέθη — ποτέ ονόματα αρχείων ή περιεχόμενο (το repository είναι δημόσιο).
import fs from 'node:fs'; import path from 'node:path';
const [,, outDir] = process.argv;
const REF = process.env.PROJECT_REF, TOKEN = process.env.SUPABASE_ACCESS_TOKEN;
const BASE = `https://${REF}.supabase.co`;
const keys = await (await fetch(`https://api.supabase.com/v1/projects/${REF}/api-keys?reveal=true`, { headers:{ Authorization:`Bearer ${TOKEN}` } })).json();
const k = Array.isArray(keys) && (keys.find(x=>x.name==='service_role') || keys.find(x=>x.type==='secret'));
if(!k || !k.api_key){ console.error('Δεν βρέθηκε κλειδί service_role'); process.exit(1); }
const KEY = k.api_key; console.log(`::add-mask::${KEY}`);
const H = { apikey: KEY, Authorization: `Bearer ${KEY}` };
const buckets = await (await fetch(`${BASE}/storage/v1/bucket`, { headers:H })).json();
if(!Array.isArray(buckets)){ console.error('Αποτυχία λίστας buckets'); process.exit(1); }
let files = 0, bytes = 0, failed = 0;
async function list(bucket, prefix){
  const out = []; let offset = 0;
  for(;;){
    const r = await fetch(`${BASE}/storage/v1/object/list/${bucket}`, { method:'POST', headers:{ ...H, 'Content-Type':'application/json' }, body: JSON.stringify({ prefix, limit:1000, offset, sortBy:{ column:'name', order:'asc' } }) });
    const a = await r.json(); if(!Array.isArray(a)) throw new Error('list failed');
    out.push(...a); if(a.length < 1000) break; offset += 1000;
  }
  return out;
}
async function walk(bucket, prefix){
  for(const e of await list(bucket, prefix)){
    const p = prefix ? `${prefix}/${e.name}` : e.name;
    if(e.id === null || !e.metadata){ await walk(bucket, p); continue; }   // φάκελος
    const r = await fetch(`${BASE}/storage/v1/object/authenticated/${bucket}/${p.split('/').map(encodeURIComponent).join('/')}`, { headers:H });
    if(!r.ok){ failed++; continue; }
    const buf = Buffer.from(await r.arrayBuffer());
    const dst = path.join(outDir, bucket, p); fs.mkdirSync(path.dirname(dst), { recursive:true }); fs.writeFileSync(dst, buf);
    files++; bytes += buf.length;
  }
}
for(const b of buckets) await walk(b.name, '');
console.log(`Storage: ${buckets.length} buckets, ${files} αρχεία, ${(bytes/1048576).toFixed(1)} MB${failed ? `, ${failed} απέτυχαν` : ''}`);
if(failed) process.exit(2);
