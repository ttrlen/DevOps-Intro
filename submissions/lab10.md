# Lab 10 — Cloud Computing: QuickNotes release and deployment

> The remaining evidence placeholders are intentionally retained until their
> measurements are observed. No latency, cold-start or external-network result
> is claimed before it is measured.

## Task 1 — Git tag to GHCR

The release workflow is [`release.yml`](../.github/workflows/release.yml). It
starts only for tags matching `v*`, builds `app/` as `linux/amd64`, and pushes:

```text
ghcr.io/ttrlen/devops-intro/quicknotes:v0.1.0
ghcr.io/ttrlen/devops-intro/quicknotes:latest
```

It has only `contents: read` and `packages: write`; every external action is
pinned to its full 40-character commit SHA. The workflow uses its automatically
scoped `GITHUB_TOKEN` to log in to GHCR and keeps the Render deploy-hook URL in
the `RENDER_DEPLOY_HOOK_URL` Actions secret. The hook is skipped while that
secret is absent, so the first `v0.1.0` push can publish the image used when
creating the Render service. After adding the secret, `v0.1.1` proves the
end-to-end `tag → push → deploy-hook` path.

### Release evidence

| Check | Evidence to record after release |
|---|---|
| Signed tags | `v0.1.0` (initial image) and `v0.1.1` (CI-to-Render deploy) |
| Green GitHub Actions run | [`v0.1.1` run #2](https://github.com/ttrlen/DevOps-Intro/actions/runs/37821921600), completed successfully on 2026-10-08. It built/pushed the `linux/amd64` image and its `Trigger Render deploy for this immutable tag` step succeeded. |
| Public package URL | `https://github.com/ttrlen/DevOps-Intro/pkgs/container/devops-intro%2Fquicknotes` |
| Clean unauthenticated pull | `docker pull ghcr.io/ttrlen/devops-intro/quicknotes:v0.1.0` succeeded; digest `sha256:31c09df5fe7fc20c9dc21322f297a7a15a05a07a15dfcf0aa2361f5e31dc9eb8`, platform `linux/amd64`. |

### Design answers

**a) OIDC versus `GITHUB_TOKEN`.** `GITHUB_TOKEN` is sufficient here because
the workflow publishes to the package belonging to the same GitHub repository.
For a cloud provider or another account, OIDC gives the job a short-lived,
verifiable identity token that the provider can exchange for narrowly scoped
credentials; no long-lived cloud secret needs to be stored in GitHub.

**b) `latest` and immutable tags.** A version tag identifies the exact artifact
for rollback, audit and deployment pinning. `latest` is a convenient moving
pointer for developer pulls and consumers that explicitly want the newest
release. Production deployments should pin a version or digest, not `latest`.

**c) Narrow permissions.** This follows least privilege. A compromised action
or malicious dependency in this job can publish packages, but cannot alter
repository contents, create releases, change issues or access other `write: all`
capabilities. That containment prevents a package-publishing workflow from
turning into a source-code or workflow-tampering attack.

## Task 2 — Option A: Render

I use Render's **Free** web-service plan, sourced from the public immutable
GHCR image. The complete dashboard configuration and rationale are in
[`cloud/render.md`](../cloud/render.md). The release workflow invokes Render's
secret deploy hook only after the image push succeeds; the hook receives the
tag as a URL-encoded `imgURL` parameter.

### Deployment and port evidence

| Check | Observed evidence |
|---|---|
| Service URL | `https://quicknotes-v0-1-0.onrender.com/` |
| `/health` verbose curl | On 2026-10-08: `HTTP/2 200`; `content-type: application/json`; body `{"notes":4,"status":"ok"}`. TLS certificate hostname matched `quicknotes-v0-1-0.onrender.com`. |
| Port log | `2026/10/08 18:02:53 quicknotes listening on :10000 (notes loaded: 4)` |
| No port-detection restart | Initial deploy log reached `Your service is live` without a `New primary port detected` entry. |
| CI hook invocation | [`v0.1.1` Actions run #2](https://github.com/ttrlen/DevOps-Intro/actions/runs/37821921600): `Trigger Render deploy for this immutable tag` completed successfully. |

### Latency and ephemeral-storage evidence

| Measurement | Result |
|---|---:|
| Five warm requests | 1.672334 s, 0.865970 s, 0.450243 s, 0.677996 s, 0.409233 s (2026-10-08) |
| Warm p50 | 0.677996 s |
| Cold request 1 after ≥20 min idle | 12.834427 s; `/health` returned HTTP 200 (2026-10-08) |
| Cold request 2 after ≥20 min idle | 13.803815 s; `/health` returned HTTP 200 (2026-10-08) |
| Cold request 3 after ≥20 min idle | 14.325977 s; `/health` returned HTTP 200 (2026-10-08) |
| Note after spin-down and wake | `POST /notes` created `id: 5`, title `lab10-ephemeral-check`; after the 20-minute sleep/wake, `GET /notes` contained only the four seed notes, so `id: 5` disappeared. |

### Design answers

**d) Render spin-down versus Cloud Run scale-to-zero.** Both remove idle
compute, but Render's free service optimizes low-cost shared infrastructure and
can need a new instance/image startup, so wake-up is roughly on the order of a
minute. Cloud Run is engineered for serving workloads with faster autoscaling,
container concurrency and managed capacity, so its scale-from-zero is normally
much shorter.

**e) `PORT` and `EXPOSE`.** `EXPOSE` is image metadata, not a reliable runtime
contract for a multi-tenant host. Render allocates/routs a port through the
runtime `PORT` environment variable. It injects `PORT=10000`; setting
`ADDR=:10000` makes QuickNotes listen there. A mismatch makes Render discover a
different primary port and restart the deploy, adding roughly another startup
cycle to every deployment.

**f) Existing image versus Render build, and the note.** An existing immutable
GHCR image is reproducible and is the same artifact scanned in Lab 9; it can
also require a registry pull for each deploy. A Render build from Git is simpler
to connect and can reuse build cache, but the resulting image can drift from the
one tested/scanned in CI. Without a persistent disk, Render's ephemeral
filesystem is discarded when the instance is replaced after spin-down, so a
POSTed note disappears after wake-up; the evidence row above records the actual
observation.

## Bonus — Cloudflare Tunnel

The reproducible quick-tunnel commands, external-network verification command
and benchmark command are in [`cloud/tunnel.md`](../cloud/tunnel.md). The URL
is intentionally not stable and must be checked from a phone on cellular (or a
different network) before it is reported.

### Attempted, but blocked by the network

I attempted the bonus on 2026-10-08 from both WSL and native Windows.  I
installed `cloudflared 2026.10.0`, tried a Cloudflare DoH/DNS workaround and a
native Windows run, then also retried with official `cloudflared 2025.11.1`.
Quick-tunnel URLs were allocated, but none registered a usable origin
connection, so I did not claim a public `/health` response, phone verification,
or latency measurement.

The final native-Windows diagnostic reached a healthy pre-check: DNS resolution
for both edge regions, UDP/QUIC, TCP/HTTP2 and the Cloudflare API all reported
`PASS`. Registration nevertheless failed immediately with:

```text
Failed to initialize DNS local resolver: lookup region1.v2.argotunnel.com: i/o timeout
Register tunnel error from server side: context deadline exceeded
```

The 2025.11.1 retry then reported QUIC control-stream failures and
`timeout: no recent network activity`. Earlier attempts on the university
network also reported that outbound TCP and UDP port 7844 to the Cloudflare edge
were blocked. This is an external network restriction, not a QuickNotes error:
the local service remained available at `http://localhost:8080` and all Render
checks above passed. The bonus can be repeated later from an unrestricted
network without changing the application or release image.

| Metric | Render | Cloudflare Tunnel (local via edge) |
|---|---:|---:|
| Warm p50 | 0.677996 s | not measured (tunnel did not register) |
| Warm p95 | not measured | not measured (tunnel did not register) |
| Cold start | 12.834427–14.325977 s | N/A (local container stays running) |
| Public URL stability | stable | ephemeral on restart |
| Cost | free | free |

### Bonus evidence

| Check | Observed evidence |
|---|---|
| Tunnel URL | Quick-tunnel URLs were allocated during diagnostics but never became usable; not reported as a deployment URL. |
| Different-network `/health` request | Not performed: an origin connection was never registered. |
| 50-run benchmark | Not performed: an origin connection was never registered. |

### Design answers

**g) Architecture.** Render runs the workload in the provider's datacenter.
The quick tunnel keeps QuickNotes on the laptop and makes an outbound connection
to Cloudflare, whose edge proxies users' requests. Both are cloud-assisted from
a user's perspective; the important distinction is operational ownership,
availability and where data/compute reside.

**h) Latency dominators.** Warm Render latency is mostly Internet path and
provider edge-to-instance routing (plus normal application work). A tunnel adds
the user-to-Cloudflare path and the Cloudflare-to-laptop path, so the laptop's
uplink, last-mile network and geographic placement are typically dominant.

**i) Appropriate production use.** Cloudflare Tunnel can be appropriate for a
managed on-prem/home-lab service, securely exposing an internal application, or
a temporary stakeholder-review URL. It is not the right production host for a
laptop-only service that needs reliable capacity, durable data, independent
operations or predictable availability.
