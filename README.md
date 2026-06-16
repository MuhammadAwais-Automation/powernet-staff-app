<div align="center">

# PowerNet Staff App

### Flutter companion app for ISP field teams, recovery agents, operators, and customers.

![Flutter](https://img.shields.io/badge/Flutter-Dart-111111?style=flat-square&logo=flutter)
![Supabase](https://img.shields.io/badge/Supabase-Backend-111111?style=flat-square&logo=supabase)
![Mobile](https://img.shields.io/badge/Mobile-Field%20Operations-111111?style=flat-square)
![Status](https://img.shields.io/badge/Portfolio--safe-Public%20Showcase-111111?style=flat-square)

</div>

PowerNet Staff App is the mobile side of the PowerNet ISP management system. It gives field users focused workflows for customer lookup, complaint handling, bill collection, payment verification, receipt upload, and customer self-service.

## At a Glance

| Area | Details |
|---|---|
| Product type | Multi-role ISP mobile app |
| Users | Field agents, recovery agents, cable operators, customers |
| Backend | Supabase Auth and data APIs |
| Mobile stack | Flutter, Dart, go_router, environment-based config |
| Showcase value | Real field workflow design connected to backend operations |

## What It Proves

| Capability | Example in this project |
|---|---|
| Mobile operations UX | Role-specific screens for field, recovery, operator, and customer flows |
| Backend integration | Supabase-backed authentication and data access |
| Field-service workflows | Customer lookup, complaint status, bill collection, payment visits |
| Media handling | Receipt upload flow with Cloudinary configured through environment variables |
| Offline thinking | Queue support for selected payment and visit actions |

## Roles

| Role | Workflow |
|---|---|
| Field Agent | Assigned customers, customer details, and field work |
| Recovery Agent | Payment collection, visit tracking, and bill recovery |
| Cable Operator | Cable/operator-side customer workflows |
| Customer | Bills, complaints, profile, and signup status |

## Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter, Dart |
| Routing | go_router |
| Backend | Supabase |
| Config | flutter_dotenv |
| Media | Cloudinary unsigned upload preset |
| State | Provider-style app state |

## Environment

Update the placeholder `assets/.env` values before running against a real backend:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
CLOUDINARY_CLOUD_NAME=your_cloudinary_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_unsigned_upload_preset
```

The committed file contains placeholder values only. Never commit real production credentials.

## Run Locally

```bash
flutter pub get
flutter run
```

## Project Map

```text
lib/
  app/          Router and app setup
  config/       Supabase and environment configuration
  data/         Repository classes
  models/       Domain models
  providers/    App state providers
  screens/      Role-based screens
  services/     Auth, customer auth, uploads
assets/
  app_icon/     App icon assets
```

## Portfolio Note

This public repository is prepared as a portfolio-safe showcase. Real credentials, local generated artifacts, and private deployment data are excluded.
