# Tabet Production System

Production area dashboard and supervised employee station, connected to Supabase PostgreSQL.

## Open the app
Private hosted preview: https://tabet-tps-production.tabet-manufa-9018.chatgpt.site

Source repository: https://github.com/jonahm-CCS/TPS

Static frontend lives in `dist/`; serve that folder with any static web server. There is no build step or JavaScript package dependency. `python3 -m http.server 8080 --directory dist` runs a local preview.

## Current status
- Supabase TPS project configured; public publishable key and URL in `dist/cloud.js`.
- Six production areas, ten sample employees, and ten sample jobs seeded.
- Shared reads, assignments, claims, start/pause/complete, work requests and display settings use authenticated database RPCs.
- Other signed-in stations refresh every 15 seconds. Writes use a locked workspace revision and reject stale updates; they never silently overwrite another station's change.
- A signed-in, explicitly approved administrator must open the shared workspace. **Initial administrator approval/account setup is pending.**
- Local browser demo remains available separately and cannot write to Supabase.
- Badge `TPS-1001` selects Jonah's Weld Shop workspace within the signed-in supervisor session. This is supervised testing, not independent employee authorization. Dedicated kiosk/employee roles and short-lived badge sessions remain future work.
- The PDF is a generic demonstration document. Private job-specific document storage is not implemented.
- The GitHub repository contains code and synthetic seed data only. Repository visibility is public, as configured by its owner. Supabase data is not publicly readable.

## First administrator setup
1. Select the exact administrator email. Access must be explicitly approved; no admin email has been pre-granted.
2. In Supabase TPS → Authentication → Users, create an email/password application user and confirm its email. This is separate from the Supabase dashboard account. Keep its password private.
3. Through a trusted database administrator, add only the approved lowercase email to `tps_private.admin_emails`. This table is inaccessible to frontend clients. The authorization helper also checks the authenticated user's real `auth.users` record and confirmed email; editable user metadata cannot grant access.
4. Sign in to TPS using that application's email/password. A sign-in session alone does not grant access unless approved.

## Database
`db/schema.sql` is the exact initial schema snapshot, applied remotely as migration `tps_shared_workspace`. `db/seed.sql` inserts sample records without overwriting existing records. Do not rerun schema.sql on an existing database. Apply subsequent DDL as versioned migrations and retain migration history.

Tables: production_areas, employees, jobs, operations, workspace_settings, work_events. All public tables have RLS and explicit administrator-only policies. A private admin email allowlist is denied to client roles. `tps_private.is_admin()` is a deliberately privileged, stable, fixed-search-path helper checking auth.uid(), confirmed email and the private allowlist; it is not exposed as a public API RPC.

Public RPCs are SECURITY INVOKER and explicitly denied to anonymous users:
- `tps_snapshot()` returns shared board data.
- `tps_command(action, job_id, employee_id, setting_key, setting_value, expected_revision)` handles workflow transitions atomically and records the authenticated actor.

The partial unique index enforces at most one running operation per employee. Commands validate area membership, job status and stale revisions. This initial access model grants approved admins direct database write privileges under RLS as well; it is not an employee permission boundary.

## Portability
The UI talks through `CloudRepository` in `dist/cloud.js`. Replace that repository's authentication/RPC implementation when moving to an internal API and local PostgreSQL. Tables and command semantics can be retained; Supabase auth helpers and policies must be adapted to the local identity service. No hosted vendor key with elevated access is embedded in the app.

## Important boundaries
Sample workloads and dates are not live shop data. Completion marks the whole current operation complete; partial completions and routing advancement are future work. No real drawing or CUI has been uploaded. GitHub source upload does not install Supabase's optional GitHub branching integration, and GitHub pushes do not yet automatically redeploy the private hosted preview.

## Validation
JavaScript syntax checked; schema application and seed counts verified; anonymous/unapproved access checked; advisor review performed. Interactive badge/job UI tested using local demo. Full signed-in shared workflow testing awaits an approved application user.
