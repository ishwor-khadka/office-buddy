# office_health_app

A new Flutter project.

## Supabase (Free Backend)

This app supports Supabase for tracking events (stress sessions, breaks, posture checks, exercises, etc).

### 1) Create a free Supabase project

- Create a project in Supabase.
- Copy your `Project URL` and `anon public` key.

### 2) Create the `tracking_events` table

Run this in Supabase SQL Editor:

```sql
create extension if not exists pgcrypto;

create table if not exists public.tracking_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  type text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.tracking_events enable row level security;

create policy "tracking_events_insert_own"
on public.tracking_events
for insert
to authenticated
with check (user_id = auth.uid());

create policy "tracking_events_select_own"
on public.tracking_events
for select
to authenticated
using (user_id = auth.uid());
```

This app syncs to Supabase only when the user is signed in.

### 3) Run the app with Supabase config

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# office-buddy
