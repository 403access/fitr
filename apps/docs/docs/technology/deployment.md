---
sidebar_position: 7
title: Deployment
---

# Deployment

:::info[Current state]
The deployment workflow is committed and verified by a local GitHub Pages simulation, but no
remote has been configured yet. Push the repository and enable Pages to make the URLs below
live. See **GitHub Pages → One-time repository setup**.
:::

There are two independent deployment surfaces:

1. **Static sites** — marketing site and documentation, deployed together to GitHub Pages.
2. **API server** — self-hosted Bun process with a persistent SQLite volume.

The iOS app is distributed through Xcode/TestFlight/App Store and points at the API URL.

## GitHub Pages (docs + marketing)

### What gets published

```text
https://<owner>.github.io/<repo>/          ← apps/web (marketing)
https://<owner>.github.io/<repo>/docs/     ← apps/docs (Docusaurus)
```

Both are built by `.github/workflows/deploy-pages.yml` and uploaded as one Pages artifact.
Using a single site avoids two Pages environments and two DNS/custom-domain setups.

### One-time repository setup

1. Push the repository to GitHub as `<owner>/<repo>`.
2. Go to **Settings → Pages → Build and deployment** and set **Source** to **GitHub Actions**.
3. Ensure Actions are allowed to create deployments (default for repositories with Pages enabled).
4. Push to `main`, or run the workflow manually from the Actions tab.

No repository secrets are required. The workflow derives the owner and repository name from
`GITHUB_REPOSITORY`, so forks deploy to their own Pages URL automatically.

### Base URL logic

Docusaurus needs to know its public path at build time. The config computes:

```ts
const repository = process.env.GITHUB_REPOSITORY ?? 'YOUR_GITHUB_USERNAME/fitr';
const [owner, project] = repository.split('/');
const baseUrl = process.env.DOCUSAURUS_BASE_URL ?? `/${project}/docs/`;
```

This produces:

- assets under `/<repo>/docs/assets/...`
- internal doc links prefixed with `/<repo>/docs/`
- the navbar “Website” link pointing at `https://<owner>.github.io/<repo>/`

If the repository is renamed, the workflow follows automatically. If you use a custom domain,
set `DOCUSAURUS_URL` and `DOCUSAURUS_BASE_URL` in the workflow (for example `https://fitr.example`
and `/docs/`).

### Local production build

```bash
cd apps/docs
GITHUB_REPOSITORY=owner/fitr bun run build
bun run serve
```

The output is in `apps/docs/build`. The marketing site has no build step; it is plain
HTML/CSS/JS in `apps/web`.

### Assembling the artifact manually

```bash
rm -rf _site && mkdir -p _site
cp -R apps/web/. _site/
rm -rf _site/node_modules _site/assets/screenshots
mkdir -p _site/docs
cp -R apps/docs/build/. _site/docs/
```

The screenshot exclusion is unnecessary in CI because `apps/web/assets` contains only the
optimized images you want to serve.

### Troubleshooting Pages

| Symptom | Cause | Fix |
| --- | --- | --- |
| Blank page, 404 assets | Wrong `baseUrl` | Set `DOCUSAURUS_BASE_URL` to `/<repo>/docs/` |
| Docs links escape `/docs` | Missing base URL during build | Rebuild with the correct env |
| Workflow cannot deploy | Pages source not set to Actions | Change it in repository settings |
| `deploy-pages` 403 | Missing `pages: write` / `id-token: write` | Check workflow permissions |
| Marketing site works, docs 404 | Docs copied to the wrong directory | Verify `_site/docs/index.html` exists |

## API server

### Local

```bash
bun install
bun run --cwd apps/server start
```

### Production guidance

The server is a single Bun process with a local SQLite file. Any host that provides a persistent
volume works:

- a small VPS with systemd or Docker;
- Fly.io with a volume mounted at `/data`;
- Railway/Render with a persistent disk;
- a home machine behind Tailscale or a reverse proxy.

A minimal Dockerfile:

```dockerfile
FROM oven/bun:1.4-slim
WORKDIR /app
COPY package.json bun.lock ./
COPY apps/server/package.json apps/server/package.json
RUN bun install --frozen-lockfile
COPY apps/server apps/server
ENV FITR_DB=/data/fitr.sqlite
ENV PORT=8787
VOLUME /data
EXPOSE 8787
CMD ["bun", "apps/server/src/index.ts"]
```

Run it:

```bash
docker build -t fitr-api .
docker run -p 8787:8787 -v fitr-data:/data fitr-api
```

### Required production changes

The current server is a trusted-LAN MVP. Before exposing it publicly:

1. **TLS** — terminate at a reverse proxy (Caddy, nginx, Fly, Railway).
2. **Authentication** — add a bearer token or OIDC provider and derive the user from it.
   Replace the `x-user-id` middleware.
3. **CORS** — restrict to the deployed marketing/docs origins or remove it entirely.
4. **Rate limiting** — add per-IP and per-user limits for writes.
5. **Backups** — schedule `sqlite3 fitr.sqlite ".backup /backups/fitr-$(date).sqlite"`.
6. **Secrets** — do not ship the demo seed to a public instance; gate it behind an env flag.
7. **Observability** — structured logs, request IDs and a `/api/health` uptime check.
8. **Disable cleartext** — remove `NSAllowsArbitraryLoads` from the iOS Info.plist and use HTTPS.

These tasks are part of the roadmap’s production-hardening phase.

### Database lifecycle

- The schema is applied idempotently at startup.
- The demo seed runs only when the exercises table is empty.
- `FITR_DB` points at the SQLite file; the parent directory is created automatically.
- WAL mode creates `-wal` and `-shm` files; back up the database with a checkpoint or the
  `.backup` command, not by copying only the main file while the server is writing.

### Environment

| Variable | Production suggestion |
| --- | --- |
| `PORT` | `8787` (or platform-provided) |
| `FITR_DB` | `/data/fitr.sqlite` |
| `NODE_ENV` | `production` |

`NODE_ENV=production` keeps request logging on; set `NODE_ENV=test` only in tests.

## iOS distribution

The app is not on the App Store. To install it on a device:

1. Open `apps/ios/Fitr.xcodeproj`.
2. Select the **Fitr** target → Signing & Capabilities.
3. Choose your development team and a unique bundle identifier.
4. Confirm the **HealthKit** capability is present and all usage descriptions are in the
   generated Info.plist (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`,
   `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`).
5. Confirm `UIBackgroundModes` contains `location` if you want route recording to continue while
   the app is backgrounded.
6. Connect a device and run.
7. On first launch, open **Health → Connect Apple Health** and grant the categories you want
   Fitr to read and write.
8. Open **Health → Routes** to import existing workout routes. Enable recording and choose
   **Always** only if you want continuous all-day movement history.

For TestFlight, create an App Store Connect record, set the bundle identifier and version to
match, archive, and upload with Xcode Organizer. Remember to point the connection settings at
your deployed HTTPS API and remove the development ATS exception.

## Custom domain

1. Add a `CNAME` file to the Pages artifact with the domain (for example `fitr.example`).
2. Configure the domain in **Settings → Pages**.
3. Set DNS: `CNAME <owner>.github.io` for a subdomain, or A/AAAA records for an apex.
4. Set `DOCUSAURUS_URL=https://fitr.example` and `DOCUSAURUS_BASE_URL=/docs/` in the workflow.
5. Re-run the deployment.

## Release checklist

- [ ] `bun run test` passes.
- [ ] `bun run --cwd apps/server typecheck` passes.
- [ ] iOS tests pass on a simulator.
- [ ] `bun run export:catalog` is current.
- [ ] Docs build with no broken links.
- [ ] Screenshots reflect the current UI.
- [ ] `apps/ios/Fitr/App/AppConfig.swift` points at the real owner.
- [ ] Database backup exists before deploying server changes.
- [ ] Version and changelog are updated.
- [ ] GitHub Pages deployment is green.
