# Tabet Production System

Open production dashboard and badge-selected employee station using Supabase PostgreSQL. No application login is required, explicitly authorized by the owner.

App: https://tabet-tps-production.tabet-manufa-9018.chatgpt.site

Serve `dist/` with any static server. No build step or package dependencies.

## Employee badge QR deep links
Each badge QR contains the TPS site URL and the employee's existing badge key, e.g.
`https://tabet-tps-production.tabet-manufa-9018.chatgpt.site/?badge=TPS-1001`.
When the employee station application loads, `dist/app.js` reads the `badge` parameter, looks up the employee's matching `employees.badge`, and opens that employee's console automatically, bypassing the landing-page badge form. `#badge=TPS-1001` is also supported as a fragment-based alternative. The USB scanner input accepts either `TPS-1001` or the full same-site badge URL. The badge does not automatically clock someone in or out.

**Deployment is manual:** GitHub commits do not update the hosted `chatgpt.site` application. After a commit, publish the new version of `dist/app.js` to the same hosted site (or redeploy all of `dist/`). Existing printed QR codes will not auto-open the console until the hosted JavaScript is updated. To verify, scan the QR into a fresh browser tab and ensure it displays Jonah's employee workspace directly without pressing \"Employee Station\" or submitting the badge field. Do not alter the printed QR destination unless the site's permanent production URL changes.


Six production areas; jobs above employees grouped by shift. Badge TPS-1001 selects Jonah's Weld Shop workspace. Assignment, claim, start/pause/complete, work requests, display settings and a sample PDF viewer are included. Shared stations refresh every 15 seconds. Commands reject stale revisions and enforce one running operation per employee.

Anyone with the app URL or public Supabase API can read and update the shared prototype records. Badges select a workspace; they do not authenticate a person. All seeded records are samples. No service-role secrets or real drawings are included.

## Database and portability
On a new database apply db/schema.sql, db/open_access.sql, then db/seed.sql. Both schema changes are already applied to the hosted TPS database. Do not rerun schema files on the existing database.

The CloudRepository adapter in dist/cloud.js calls PostgreSQL RPCs using a publishable project key without an account. Replace this adapter with your internal API when moving to local PostgreSQL. Adapt Supabase auth helpers then. The legacy private admin helper is unused in open mode.

RLS remains enabled, with intentionally open policies for the anonymous role. Public clients have SELECT/INSERT/UPDATE grants and no DELETE grant. RPCs run with caller privileges. Work events can have no authenticated actor.

GitHub contains source and synthetic seeds. GitHub pushes do not yet redeploy the hosted app automatically; Supabase's optional GitHub branching integration is not configured. Completion marks the whole operation; partial quantities, routing advancement and private job-specific PDFs remain future work.
