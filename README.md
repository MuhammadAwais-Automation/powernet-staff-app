# PowerNet Staff App

Flutter mobile app for ISP field teams, recovery agents, cable operators, and customers.

PowerNet Staff App is the mobile companion for the PowerNet ISP management system. It gives field users a focused workflow for customer lookup, complaint handling, bill collection, payment verification, and customer self-service.

## Highlights

- Multi-role mobile workflows for ISP operations
- Staff login through Supabase-backed authentication
- Field agent customer lists and customer detail views
- Complaint tracking and assignment support
- Billing and recovery flows for payment collection
- Customer portal for bills, complaints, profile, and signup requests
- Offline queue support for selected payment/visit actions
- Receipt upload flow with Cloudinary configuration through environment variables

## Roles

| Role | Purpose |
|---|---|
| Field Agent | View assigned customers and field details |
| Recovery Agent | Collect payments and record visits |
| Cable Operator | Manage cable/operator-side customer flows |
| Customer | View bills, complaints, profile, and signup status |

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter, Dart |
| Routing | go_router |
| Backend | Supabase |
| Config | flutter_dotenv |
| Media Uploads | Cloudinary unsigned upload preset |
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

## Project Structure

```text
lib/
  app/          Router and app setup
  config/       Supabase/environment configuration
  data/         Repository classes
  models/       Domain models
  providers/    App state providers
  screens/      Role-based screens
  services/     Auth, customer auth, uploads
assets/
  app_icon/     App icon assets
```

## Notes

This repository is prepared as a portfolio-safe showcase. Environment files, generated analysis artifacts, and private deployment data are excluded.
