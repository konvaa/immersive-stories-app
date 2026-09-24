# Immersive Stories: mobilní klient

Flutter aplikace pro textové fantasy RPG [Immersive Stories](https://github.com/konvaa/immersive-stories-api).
Hráč se přihlásí, založí nebo načte kampaň, zadává akce a čte narativ,
který generuje backend (deterministický engine + AI narace). Scény jde
nechat vizualizovat a prohlížet v archivu vizí.

> **Stav: on hold.** Vývoj je pozastavený a backend, na který aplikace
> ve výchozím stavu míří, momentálně neběží.

## Stack

- **Flutter / Dart** (SDK ^3.11)
- **supabase_flutter**: přihlášení; access token se posílá backendu jako Bearer
- **http**: volání REST API backendu (`lib/services/api_service.dart`)

## Konfigurace

Veškerá konfigurace je v [`lib/config.dart`](lib/config.dart):

| Konstanta | Význam |
|---|---|
| `apiBaseUrl` | URL backendu (FastAPI). Lokálně např. `http://10.0.2.2:8000` pro Android emulátor. |
| `supabaseUrl` | URL Supabase projektu |
| `supabaseAnonKey` | Supabase **publishable** klíč |

Publishable klíč je veřejný z principu, skončí v každé sestavené aplikaci.
Data chrání Row Level Security v Supabase. Do klienta nikdy nepatří secret
ani service_role klíč.

## Spuštění

```sh
flutter pub get
flutter run
```

Předpoklad: běžící backend na adrese z `apiBaseUrl` a Supabase projekt se
schématem z backendového repozitáře.
