# ATL Inventory
### Atal Tinkering Lab · Component Tracker

A cross-platform Flutter app for managing lab components in an Atal Tinkering Lab (ATL). Students can browse and search available equipment in real time. Admins can add, edit, and delete components — and every change reflects instantly on all connected devices via Supabase Realtime.

---

## Screenshots

> Add screenshots to a `screenshots/` folder and uncomment the lines below.

<!-- 
| Login | Inventory | Add Component |
|-------|-----------|---------------|
| ![Login](screenshots/login.png) | ![Inventory](screenshots/inventory.png) | ![Add](screenshots/add.png) |
-->

---

## Features

| Feature | Details |
|---|---|
| **Real-time sync** | Supabase Realtime — admin changes appear on all devices in ~1 second |
| **Role-based access** | Student (read-only browse) and Admin (password-protected edit) |
| **Component cards** | Image, name, category, box number, availability arc indicator |
| **Category filters** | Tap chips to filter by component type |
| **Search** | Search by name, serial number, category, or box number |
| **QR scanner** | Scan a box QR code to filter components instantly |
| **Image upload** | Admin can attach photos via camera or gallery (stored in Supabase Storage) |
| **Light / Dark mode** | Toggle from any screen — persists across the session |
| **Offline resilient** | Shows last-loaded data if network drops |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Database | Supabase (PostgreSQL) |
| Realtime | Supabase Realtime (WebSocket subscriptions) |
| Storage | Supabase Storage (part images) |
| Fonts | Google Fonts — Inter |
| QR Scanning | `mobile_scanner` |
| Image picking | `image_picker` |

---

## Project Structure

```
lib/
├── main.dart                  # App entry, Supabase init, theme tokens (light + dark)
├── assets/
│   ├── logo.jpg
│   └── default_part.jpg
└── screens/
    ├── splash_screen.dart     # Animated splash with logo
    ├── login_screen.dart      # Role selection (Student / Admin)
    ├── inventory_screen.dart  # Real-time grid, search, category chips
    ├── add_part_screen.dart   # Add / edit component form with image upload
    └── qr_scanner_screen.dart # Box QR code scanner
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.10.4`
- Dart SDK `>=3.10.4`
- Android Studio / VS Code with Flutter extension
- A [Supabase](https://supabase.com) account (free tier is enough)

### 1 — Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/atl_inventory.git
cd atl_inventory
```

### 2 — Set up Supabase

#### Create a project
1. Go to [supabase.com](https://supabase.com) → **New Project**
2. Name it `atl-inventory`, pick a region closest to you
3. Note down your **Project URL** and **anon public key** from  
   `Settings → API`

#### Run the setup SQL
Open **SQL Editor** in your Supabase dashboard and run:

```sql
-- Parts table
create table if not exists public.parts (
  id            text        primary key,
  part_name     text        not null,
  serial_no     text        default '',
  category      text        default '',
  box_no        integer     default 0,
  total_parts   integer     default 0,
  current_count integer     default 0,
  availability  integer     default 0,
  image_url     text        default '',
  last_updated  timestamptz default now()
);

-- Row Level Security
alter table public.parts enable row level security;

create policy "Public read"
  on public.parts for select using (true);

create policy "Public write"
  on public.parts for all using (true) with check (true);

-- Enable Realtime
alter publication supabase_realtime add table public.parts;

-- Storage bucket for images
insert into storage.buckets (id, name, public)
values ('part-images', 'part-images', true)
on conflict do nothing;

create policy "Public image read"
  on storage.objects for select
  using (bucket_id = 'part-images');

create policy "Public image upload"
  on storage.objects for insert
  with check (bucket_id = 'part-images');

create policy "Public image update"
  on storage.objects for update
  using (bucket_id = 'part-images');
```

#### Enable Realtime
Go to **Database → Replication** and confirm the `parts` table is included,  
or verify with:

```sql
select * from pg_publication_tables where pubname = 'supabase_realtime';
```

### 3 — Add your credentials

Open `lib/main.dart` and replace the placeholder values:

```dart
const kSupabaseUrl    = 'https://YOUR_PROJECT_ID.supabase.co';
const kSupabaseAnonKey = 'YOUR_ANON_KEY';
```

> **Note:** The anon key is safe to include in a mobile app — it only allows what your RLS policies permit.  
> Never commit a `service_role` key.

### 4 — Add assets

Place your logo in `lib/assets/logo.jpg`.  
A fallback "ATL" text renders automatically if the file is missing.

### 5 — Android permissions

In `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

In `android/app/build.gradle`:

```gradle
defaultConfig {
    minSdkVersion 21
    ...
}
```

### 6 — Install and run

```bash
flutter pub get
flutter run
```

---

## Admin Access

The app uses a simple password gate for admin mode.  
The default password is `aTal@2026`.

To change it, search for `aTal@2026` in the codebase and replace with your own password.  
For a production deployment, move this to a secure environment variable or Supabase Edge Function.

---

## Database Schema

```
Table: parts
┌──────────────┬─────────────┬──────────────────────────────────────────┐
│ Column       │ Type        │ Description                              │
├──────────────┼─────────────┼──────────────────────────────────────────┤
│ id           │ text (PK)   │ UUID generated by the app                │
│ part_name    │ text        │ Component name (e.g. Arduino Uno)        │
│ serial_no    │ text        │ Serial / asset number                    │
│ category     │ text        │ Used for filter chips                    │
│ box_no       │ integer     │ Physical storage box number              │
│ total_parts  │ integer     │ Total quantity in lab                    │
│ current_count│ integer     │ Same as availability (kept for compat.)  │
│ availability │ integer     │ Currently available count                │
│ image_url    │ text        │ Public URL from Supabase Storage         │
│ last_updated │ timestamptz │ Timestamp of last edit                   │
└──────────────┴─────────────┴──────────────────────────────────────────┘
```

---

## Dependencies

```yaml
supabase_flutter: ^2.0.0   # Database, Realtime, Storage
google_fonts: ^6.2.1        # Inter font
image_picker: ^1.0.4        # Camera / gallery
mobile_scanner: ^5.1.1      # QR code scanning
uuid: ^4.4.0                # UUID generation for part IDs
connectivity_plus: ^5.0.2   # Network state detection
```

---

## How Realtime Works

```
Admin edits a part on Device A
        │
        ▼
Supabase PostgreSQL (upsert)
        │
        ▼
supabase_realtime publication broadcasts change
        │
    ┌───┴───┐
    ▼       ▼
Device B  Device C
(re-fetches and updates UI instantly)
```

No polling. No manual refresh. WebSocket subscription on app launch,  
unsubscribed cleanly on screen dispose.

---

## Roadmap

- [ ] Supabase Auth (email login for admins instead of hardcoded password)
- [ ] Low-stock alerts / push notifications
- [ ] Export inventory as CSV / PDF
- [ ] Borrow / return log with student name tracking
- [ ] iOS support and TestFlight build

---

## Contributing

Pull requests are welcome. For major changes please open an issue first.

1. Fork the repo
2. Create a branch: `git checkout -b feature/your-feature`
3. Commit: `git commit -m 'Add some feature'`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request

---

## License

[MIT](LICENSE)

---

<div align="center">
  Built with ❤️ for Atal Tinkering Labs across India
</div>
