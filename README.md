# Cloudflare DNS Manager untuk WHMCS

Modul provisioning WHMCS yang mengintegrasikan **Cloudflare** langsung ke area klien Anda: zona otomatis dibuat saat layanan aktif, dan pelanggan dapat mengelola DNS record, proxy, redirect, hingga flush cache — semuanya dari halaman detail produk.

> **Nama modul / servertype:** `cfdnsmanager`

**Author:** [Rohmat Ali Wardani](https://www.linkedin.com/in/rohmat-ali-wardani/) · ✉️ rohmataliwardani@gmail.com

---

## Fitur

| Fitur | Keterangan |
|---|---|
| 1. **Provisioning otomatis** | Saat layanan dibuat (`CreateAccount`), modul menambahkan domain sebagai zona baru di Cloudflare dan menyimpan Zone ID ke *custom field* layanan |
| 2. **Terminate bersih** | `TerminateAccount` menghapus zona dari Cloudflare + data lokal |
| 3. **Kelola DNS Record** | Tambah / edit / hapus semua tipe (A, AAAA, CNAME, MX, TXT, NS, CAA, SRV) dengan validasi & normalisasi nama domain otomatis |
| 4. **Sync dua arah** | Record tersimpan di tabel lokal `mod_cfdnsmanager_records` lalu disinkronkan ke Cloudflare; status per-record: `pending`, `synced`, `failed`, `scanned` |
| 5. **Cloudflare Proxy** | Toggle proxy per record (orange/grey cloud) atau massal via bulk action — hanya tipe A/AAAA/CNAME |
| 6. **Bulk Actions** | Select-all yang menghormati filter aktif → bulk delete & bulk proxy toggle dengan konfirmasi jumlah |
| 7. **Scan & Import** | Impor DNS record existing dari nameserver sebelumnya sebelum delegasi NS dilakukan |
| 8. **Verify Nameservers** | Verifikasi NS tiga lapis: status zona `active` (otoritatif dari Cloudflare) → live DNS lookup (`dns_get_record`) pada zona `pending` → pesan error detail (NS terdeteksi vs diharapkan) |
| 9. **Flush Cache** | Purge Everything cache Cloudflare satu klik dari header halaman |
| 10. **URL Redirects** | Kelola Page Rules forwarding (301/302) dengan wildcard & capture group `$1` |
| 11. **Pencarian & Filter** | Pencarian client-side + chip filter per tipe record dalam satu tabel |
| 12. **DNS Analytics (GraphQL)** | Tab terpisah untuk memantau analitik query DNS Cloudflare (Free tier) dengan filter rentang waktu (24h, 7d, 30d), KPI queries & status, grafik tren volume, chart tipe record, dan tabel top 15 queries hostname |

---

## Persyaratan

- WHMCS 7.x / 8.x
- PHP 8.0+ dengan ekstensi **cURL** dan **DNS** (`dns_get_record`)
- Akun Cloudflare dengan akses API
- Folder modul menulis-tabel pertama kali melalui WHMCS Capsule (tidak butuh hak akses khusus)

---

## Instalasi

### 1. Salin file
Letakkan folder modul ke:

```
WHMCS_ROOT/modules/servers/cfdnsmanager/
```

Struktur akhir:

```
cfdnsmanager/
├── cfdnsmanager.php      ← modul utama
├── install.sql           ← opsional; tabel juga dibuat otomatis saat aktivasi
├── lang/
│   ├── english.php
│   ├── indonesian.php
│   └── overrides/        ← kustomisasi teks tanpa mengubah default
├── lib/
│   └── CloudflareAPI.php ← wrapper API Cloudflare
├── README.md
└── templates/
    └── dns_manager.tpl   ← UI client area
```

Tabel `mod_cfdnsmanager_records` **dibuat otomatis** oleh modul pada pemanggilan pertama — menjalankan `install.sql` secara manual tidak wajib.

### 2. Buat Custom Field
Buat *custom field* bertipe **product** bernama **`Cloudflare Zone ID`** (admin-only) — lihat **Setup → Products/Services → Custom Fields**, atau buat via grup produk:

| Setting | Nilai |
|---|---|
| Type | Product |
| Name | Cloudflare Zone ID |
| Field Type | Text |
| Admin Only | ✅ |

### 3. Konfigurasi Produk
Saat membuat/mengedit produk dengan Module `cfdnsmanager`, isi tab **Module Settings**:

| Opsi | Keterangan |
|---|---|
| **Cloudflare Email** | Email akun Cloudflare (dipakai bila autentikasi Global API Key) |
| **Cloudflare API Token** | **API Token** dengan izin `Zone:Edit` + `DNS:Edit` + `Analytics:Read` *(disarankan)*, **atau** Global API Key |
| **Cloudflare Account ID** | Account ID Cloudflare (lihat dashboard kanan atas domain) |
| **Custom Field for Zone ID** | Nama custom field tempat Zone ID disimpan. Default: `Cloudflare Zone ID` |

> **Izin API Token Cloudflare yang dibutuhkan:**
> - `Zone` → `Zone` → `Edit` (untuk membuat / mengelola zona domain)
> - `Zone` → `DNS` → `Edit` (untuk menambah, mengedit, & menghapus DNS records)
> - `Zone` → `Analytics` → `Read` (untuk membaca GraphQL Analytics API pada tab DNS Analytics)
> - *Zone Resources*: `All zones` atau spesifik zona domain Anda.
> 
> Modul mendeteksi jenis kredensial secara otomatis: token yang mengandung `@` & ≤37 karakter diperlakukan sebagai Global API Key (header `X-Auth-Email`/`X-Auth-Key`), selain itu dipakai sebagai Bearer Token.

### 4. Selesai
Layanan baru yang di-*create* akan otomatis:
1. Menambahkan domain ke Cloudflare,
2. Mendapat 2 nameserver `*.ns.cloudflare.com`,
3. Zone ID tersimpan di custom field,
4. Nameserver ditampilkan di client area + admin services tab.

---

## Panduan Pengguna Akhir (Client Area)

Setelah membuka layanan dari Client Area:

1. **Sebelum mengubah NS**, klik **Scan & Import** agar record DNS lama tersalin ke Cloudflare (menghindari downtime).
2. **Ubah nameserver** di registrar sesuai dua NS yang ditampilkan kartu *Cloudflare Nameservers*, lalu klik **Verify Nameservers**. Zona berstatus `active` langsung terverifikasi; zona `pending` dicek langsung via resolusi DNS publik.
3. Kelola record dari tabel: **Add Record**, **Edit**, **Del**, centang beberapa baris untuk **Proxy On/Off** atau **Delete Selected**.
4. Gunakan kolom pencarian + chip tipe untuk memfilter; select-all hanya mengambil baris yang terlihat.
5. **URL Redirects** — buat aturan `old.example.com/* → https://new.com/$1`. Hanya berlaku bagi trafik yang melewati proxy.
6. **Flush Cache** di header — membersihkan seluruh cache Cloudflare untuk zona.

---

## Referensi Teknis

### Skema Database — `mod_cfdnsmanager_records`

```sql
id                   int AUTO_INCREMENT PK
serviceid            int                -- relasi tblhosting.id
cloudflare_record_id varchar(255) NULL  -- ID record di sisi Cloudflare
type                 varchar(10)
name                 varchar(255)
content              text
ttl                  int DEFAULT 1      -- 1 = Auto
priority             int DEFAULT 0      -- MX/SRV
proxied              tinyint DEFAULT 0  -- hanya A/AAAA/CNAME
sync_status          enum('pending','synced','failed','scanned')
sync_error           text NULL
created_at / updated_at / synced_at  timestamp
```

Migrasi aman-idempoten: tabel dibuat bila belum ada; kolom `proxied` ditambahkan otomatis bila versi lama belum memilikinya. **Instal ulang tidak pernah menghapus data existing.**

### Action POST (`cfdnsmanager_action`)

| Action | Fungsi |
|---|---|
| `addRecord` · `editRecord` | Buat/ubah record (nama di-append `.domain` bila belum lengkap; `@` = root) |
| `deleteRecord` | Hapus record Cloudflare + sinkron DB lokal |
| `deleteLocalRecord` · `retrySync` | Hapus record gagal-sync lokal / coba kirim ulang |
| `bulkDelete` | Mass-delete (`recordIds[]` Cloudflare, `localRecordIds[]` lokal) |
| `bulkSetProxy` | Mass-toggle proxy (`recordIds[]`, `proxied=0\|1`) |
| `scanDnsRecords` | Impor record dari NS sebelumnya |
| `verifyNameservers` | Verifikasi delegasi NS |
| `addZoneManually` | Provisioning ulang zona |
| `flushCache` | Purge Everything |
| `addRedirect` · `deleteRedirect` | Kelola Page Rule forwarding |

### Endpoint Cloudflare yang dipakai

```
GET    zones/{id}                       → verifikasi NS (status/name_servers)
GET    zones/{id}/dns_records           → list record
POST   zones/{id}/dns_records           → create
PUT    zones/{id}/dns_records/{rid}     → update (+SSL auto-config saat proxied)
DELETE zones/{id}/dns_records/{rid}     → delete
POST   zones/{id}/purge_cache           → {"purge_everything": true}
GET/POST/DELETE zones/{id}/pagerules    → URL redirects
POST   zones                            → provisioning zona
GET    zones?name={domain}              → resolve zone id
```

---

## Troubleshooting

| Gejala | Penyebab umum |
|---|---|
| *"Cloudflare Zone ID not found for this service"* | Custom field `Cloudflare Zone ID` belum dibuat / masih kosong untuk layanan tsb |
| *"errorFetchingRecords..."* | API Token invalid / kurang permission — cek Setup → Module Debug Log |
| Redirect tidak berfungsi | Record source belum **proxied** (Page Rules hanya bekerja pada trafik orange-cloud) |
| Verify NS tetap "not pointing" padahal sudah benar | Zona masih `pending` di Cloudflare — propagasi bisa ≤48 jam; klik verify lagi nanti, atau tunggu sampai zona otomatis jadi `active` setelah Cloudflare memverifikasi |
| Form tidak bereaksi saat ganti tipe record | Ada JS konflik dari tema; field dinamis bergantung `<script>` di bagian bawah template |

Aktifkan **Utilities → Logs → Module Log** untuk melihat seluruh request/response API (semuanya tercatat via `logModuleCall('cfdnsmanager', ...)`).

---

## Keamanan

- Semua operasi tulis memvalidasi **ownership**: query lokal selalu difilter `serviceid`; delete/update Cloudflare hanya menerima ID alfanumerik.
- Rekomendasi produksi: gunakan **API Token** berbatasan izin (bukan Global API Key), dan batasi izin hanya pada zona yang dikelola.

## Lisensi

Internal use — silakan disesuaikan untuk kebutuhan bisnis Anda.

---

## Author & Kontak

**Rohmat Ali Wardani**

- ✉️ Email: [rohmataliwardani@gmail.com](mailto:rohmataliwardani@gmail.com)
- 💼 LinkedIn: [linkedin.com/in/rohmat-ali-wardani](https://www.linkedin.com/in/rohmat-ali-wardani/)

Untuk pertanyaan, bug report, atau permintaan fitur seputar modul ini, silakan hubungi melalui salah satu kanal di atas.
