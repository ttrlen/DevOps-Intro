# Lab 9 — DevSecOps: Trivy, ZAP and a reachability gate

Date of evidence: 2026-10-01 to 2026-10-04.  All reports referenced below
are committed under [`reports/lab9/`](../reports/lab9/).

## 1. Trivy

Trivy was pinned to `aquasec/trivy:0.59.1`; Docker volume
`trivy-cache-lab9` was used only as its cache.  I restricted vulnerability
output to `HIGH,CRITICAL`.

### Captured scan outputs

Image scan command and result summary:

```console
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy-cache-lab9:/root/.cache/ aquasec/trivy:0.59.1 \
    image --severity HIGH,CRITICAL --format json \
    --output /work/reports/lab9/trivy-image.json quicknotes:lab6
ArtifactName: quicknotes:lab6
ArtifactType: container_image
OS: debian 13.7
Targets: healthcheck (19 HIGH), quicknotes (19 HIGH)
CRITICAL: 0; HIGH: 38 report records
```

The complete machine-readable result is
[`trivy-image.json`](../reports/lab9/trivy-image.json).  The first lines of
that output identify the scanned immutable image:

```json
{
  "SchemaVersion": 2,
  "CreatedAt": "2026-10-01T10:05:08.996228255Z",
  "ArtifactName": "quicknotes:lab6",
  "ArtifactType": "container_image",
  "Metadata": {
    "OS": { "Family": "debian", "Name": "13.7" },
    "ImageID": "sha256:bccde6459b15ce2336c7c46202b691a5880d018f2585a5ff227e4539b3275c74"
  }
}
```

Filesystem scan:

```console
$ docker run --rm -v trivy-cache-lab9:/root/.cache/ -v "$PWD:/work" \
    -w /work aquasec/trivy:0.59.1 fs --severity HIGH,CRITICAL \
    --format json --output /work/reports/lab9/trivy-fs.json /work
ArtifactName: /work
ArtifactType: filesystem
Target: app/go.mod (gomod)
HIGH: 0; CRITICAL: 0
```

See [`trivy-fs.json`](../reports/lab9/trivy-fs.json).

Configuration scan:

```console
$ docker run --rm -v "$PWD:/work" -w /work aquasec/trivy:0.59.1 \
    config --skip-policy-update --format json \
    --output /work/reports/lab9/trivy-config.json /work
Target: app/Dockerfile
HIGH: 0; CRITICAL: 0
```

See [`trivy-config.json`](../reports/lab9/trivy-config.json).  It also
contains one *LOW* `DS026` (“No HEALTHCHECK defined”); it is outside the
required HIGH/CRITICAL triage set.  The final run used the embedded policy
checks because the then-downloaded policy bundle was incompatible with this
pinned Trivy release.

SBOM generation:

```console
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy-cache-lab9:/root/.cache/ -v "$PWD:/work" -w /work \
    aquasec/trivy:0.59.1 image --format cyclonedx \
    --output /work/reports/lab9/quicknotes-lab6.cdx.json quicknotes:lab6
```

[`quicknotes-lab6.cdx.json`](../reports/lab9/quicknotes-lab6.cdx.json) is the
complete CycloneDX 1.6 SBOM.  Its first 30 lines are:

```json
{
  "$schema": "http://cyclonedx.org/schema/bom-1.6.schema.json",
  "bomFormat": "CycloneDX",
  "specVersion": "1.6",
  "serialNumber": "urn:uuid:121e57ed-74bf-4271-b1bd-13fc485cfd2f",
  "version": 1,
  "metadata": {
    "timestamp": "2026-10-01T10:07:37+00:00",
    "tools": {
      "components": [
        {
          "type": "application",
          "group": "aquasecurity",
          "name": "trivy",
          "version": "0.59.1"
        }
      ]
    },
    "component": {
      "bom-ref": "pkg:oci/quicknotes@sha256%3Abccde6459b15ce2336c7c46202b691a5880d018f2585a5ff227e4539b3275c74?arch=amd64&repository_url=index.docker.io%2Flibrary%2Fquicknotes",
      "type": "container",
      "name": "quicknotes:lab6",
      "purl": "pkg:oci/quicknotes@sha256%3Abccde6459b15ce2336c7c46202b691a5880d018f2585a5ff227e4539b3275c74?arch=amd64&repository_url=index.docker.io%2Flibrary%2Fquicknotes",
      "properties": [
        {
          "name": "aquasecurity:trivy:DiffID",
          "value": "sha256:187cfc6d1e3e8a40a5e64653bcd3239c140807dcf1c09e48021178705a5a6139"
        },
        {
          "name": "aquasecurity:trivy:DiffID",
          "value": "sha256:275a30dd8ce958b21daa9ad962c6fbc09f98306ee2f486b65c9075dc257b1412"
```

### HIGH/CRITICAL triage

There are no HIGH/CRITICAL records in the filesystem or configuration report.
The image report has 38 records: each of the 19 CVEs below is reported once
for `healthcheck` and once for `quicknotes`, both compiled with Go stdlib
`v1.24.13`.  Thus every individual HIGH record is covered by its CVE row.

All rows have the same bounded disposition: **ACCEPT until 2026-12-31**.  The
image is a local course-lab deployment, with no production data or public
Internet deployment.  This is not a claim that the CVEs are harmless: an
upgrade of the build/runtime Go release to a supported patched release is
required before production deployment, and the decision must be revisited by
the stated date.

| Finding (applies to both binaries) | Installed → fixed version | Severity | Disposition and reason |
|---|---|---|---|
| CVE-2026-25679 | stdlib `v1.24.13` → `1.25.8` / `1.26.1` | HIGH ×2 | ACCEPT; local lab context; re-evaluate 2026-12-31. |
| CVE-2026-27145 | `v1.24.13` → `1.25.11` / `1.26.4` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-32280 | `v1.24.13` → `1.25.9` / `1.26.2` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-32281 | `v1.24.13` → `1.25.9` / `1.26.2` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-32283 | `v1.24.13` → `1.25.9` / `1.26.2` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-33811 | `v1.24.13` → `1.25.10` / `1.26.3` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-33814 | `v1.24.13` → `1.25.10` / `1.26.3` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-33818 | `v1.24.13` → `1.25.13` / `1.26.6` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-39820 | `v1.24.13` → `1.25.10` / `1.26.3` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-39821 | `v1.24.13` → `1.25.13` / `1.26.6` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-39822 | `v1.24.13` → `1.25.12` / `1.26.5` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-39836 | `v1.24.13` → `1.25.10` / `1.26.3` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-42499 | `v1.24.13` → `1.25.10` / `1.26.3` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-42504 | `v1.24.13` → `1.25.11` / `1.26.4` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-56853 | `v1.24.13` → `1.25.13` / `1.26.6` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-56858 | `v1.24.13` → `1.25.13` / `1.26.6` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-56859 | `v1.24.13` → `1.25.13` / `1.26.6` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-56860 | `v1.24.13` → `1.25.13` / `1.26.6` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |
| CVE-2026-56862 | `v1.24.13` → `1.25.13` / `1.26.6` | HIGH ×2 | ACCEPT; same bounded upgrade plan. |

### Design answers

**a) Severity is not the answer.**  Triage also considers whether this
application reaches the vulnerable code, whether a network attacker can reach
it, authentication and deployment exposure, exploit maturity, data impact,
available patches, and compensating controls.  A HIGH in a local teaching
container and a HIGH in an Internet-facing payment service are not the same
operational risk.

**b) Why a minimal/distroless base helps.**  It removes package managers,
shells, utilities and libraries that the application does not need.  Fewer
components mean fewer CVEs, fewer reachable attack paths and less patching
work.  It is not a substitute for updating the application and its runtime.

**c) `.trivyignore`.**  It is appropriate only for a documented false
positive or a consciously accepted risk with scope, owner and expiry/review
date.  Ignoring a finding merely to turn a dashboard green, or without a
reassessment date, hides risk rather than reducing it.

**d) Future value of the SBOM.**  When a new incident such as Log4Shell is
announced, the SBOM answers whether this exact image digest contains the
affected component/version without rebuilding or guessing.  It lets an owner
quickly identify which deployed artifacts need remediation.

## 2. OWASP ZAP baseline and security-header fix

Only passive `zap-baseline.py` was used; no active ZAP scan was run.  The ZAP
image was immutable-pinned as
`ghcr.io/zaproxy/zaproxy@sha256:84d2459dc305354fc2bcefc1e4d29a6bad830746891ee59c14f7cfbe136ce4ff`.

The required baseline target was `http://localhost:8080`; its root is not an
application route and returns 404, so I also ran the same passive baseline
against the real API endpoint `http://localhost:8080/health`.  This made the
header finding observable while retaining the required root report.

```console
$ docker run --rm -t --user 0:0 --network host \
    -v "$PWD/reports/lab9:/zap/wrk/:rw" \
    ghcr.io/zaproxy/zaproxy@sha256:84d2459dc305354fc2bcefc1e4d29a6bad830746891ee59c14f7cfbe136ce4ff \
    zap-baseline.py -t http://localhost:8080/health \
    -J zap-before-api.json -r zap-before-api.html
```

The raw root baseline is
[`zap-before.json`](../reports/lab9/zap-before.json) and
[`zap-before.html`](../reports/lab9/zap-before.html).  The API before-fix
baseline is [`zap-before-api.json`](../reports/lab9/zap-before-api.json) and
[`zap-before-api.html`](../reports/lab9/zap-before-api.html).  The equivalent
after-fix artifacts are [`zap-after-api.json`](../reports/lab9/zap-after-api.json)
and [`zap-after-api.html`](../reports/lab9/zap-after-api.html).

### ZAP triage

| ID and finding | Risk; affected URL(s) | Disposition and rationale |
|---|---|---|
| `10021` X-Content-Type-Options Header Missing | Low (confidence Medium); `/health` (200) in the API before report | **FIX.** Added `securityHeaders` middleware in [`app/security.go`](../app/security.go), wrapping the whole router in [`app/handlers.go`](../app/handlers.go).  [`TestSecurityHeaders_AppliedToAllRoutes`](../app/handlers_test.go) verifies `/health` and a 404 route, so removal of the outer middleware fails the test.  Fix commit: `988fdde`. |
| `10049-3` Storable and Cacheable Content | Informational (confidence Medium); root/API `/`, `/health`, `/robots.txt`, and `/sitemap.xml` as applicable | **ACCEPT until 2026-12-31.**  The 404 responses contain no sensitive data; `/health` exposes only the service status and note count.  This course API has no authenticated browser session or personal data.  Re-evaluate before adding authenticated/sensitive endpoints; then set explicit cache policy. |
| `10116` ZAP is Out of Date | Low (confidence High); root and crawler-discovered 404 URL | **FALSE POSITIVE for QuickNotes.**  This reports the scanner's own update status, not a vulnerability in the target application.  The image is digest-pinned for reproducibility and should be deliberately refreshed for later scans. |
| `90004-1` Insufficient Site Isolation Against Spectre Vulnerability | Low (confidence Medium); `/health` (200) | **ACCEPT until 2026-12-31.**  QuickNotes is a JSON API, not a rendered cross-origin document using browser shared-memory features.  Re-evaluate if a browser UI, cross-origin embedding, or `SharedArrayBuffer` use is introduced. |

### Before/after proof

Before the fix, ZAP reported:

```text
WARN-NEW: X-Content-Type-Options Header Missing [10021] x 1
        http://localhost:8080/health (200 OK)
```

The application was rebuilt and restarted, then the identical passive API
baseline was run again.  The after report contains `PASS` for alert `10021`
and has no `10021` alert entry:

```text
PASS: X-Content-Type-Options Header Missing [10021]
FAIL-NEW: 0  WARN-NEW: 3  PASS: 64
```

The code change is global middleware, not per-handler header setting:

```go
func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		next.ServeHTTP(w, r)
	})
}
```

### Design answers

**e) Middleware rather than handlers.**  One wrapper applies the policy to
existing, future and error/404 routes consistently.  Per-handler calls are
duplicated, easy to forget and cannot protect routes that are added later.

**f) `default-src 'none'`.**  It blocks all fetched/embedded browser content
unless explicitly allowed: scripts, styles, images, fonts, frames and network
connections.  That would break an ordinary web UI until it has an accurate
allowlist.  QuickNotes serves JSON rather than an HTML UI, so a strict CSP is
less disruptive there; it must still be reconsidered before adding a UI.

**g) Reading alerts matters.**  Blindly accepting everything converts the
scanner into a source of unreviewed permanent exceptions.  It hides genuine
risks among benign findings, creates alert fatigue and gives no owner or
expiry for decisions.

## 3. Bonus — `govulncheck` PR gate

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) adds a distinct
`govulncheck` job and includes it in `ci-ok`'s `needs`, so its failure blocks
the aggregate PR gate:

```yaml
  govulncheck:
    name: govulncheck
    runs-on: ubuntu-24.04
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11
      - uses: actions/setup-go@40f1582b2485089dde7abd97c1529aa768e1baff
        with:
          go-version: '1.25.13'
          cache: true
          cache-dependency-path: app/go.mod
      - run: go install golang.org/x/vuln/cmd/govulncheck@v1.1.4
      - run: |
          govulncheck_path="$(go env GOPATH)/bin/govulncheck"
          "$govulncheck_path" ./...

  ci-ok:
    needs: [vet, test, lint, govulncheck]
```

The course workflow's ordinary jobs use Go 1.24.  This security job uses
Go 1.25.13 intentionally: the Go 1.24.13 environment reported current,
reachable standard-library vulnerabilities with fixes only in Go 1.25+, so it
could not provide the required clean post-revert gate.  This is an explicit
time-bounded compatibility deviation, not a hidden suppression; it should be
normalised by upgrading the production build/runtime and the rest of CI before
production use.

### Red/green proof

For a controlled test, commit `62bb2c4` temporarily added
`golang.org/x/text@v0.3.7` and a reachable call to
`language.ParseAcceptLanguage` in `main`.  The dedicated GitHub Actions job
failed as intended:

```text
Vulnerability #1: GO-2022-1059
Module: golang.org/x/text
Found in: golang.org/x/text@v0.3.7
Fixed in: golang.org/x/text@v0.3.8
Example trace: main.go:20:40: quicknotes.main calls language.ParseAcceptLanguage
Your code is affected by 1 vulnerability from 1 module.
Error: Process completed with exit code 3.
```

`govulncheck` and `ci-ok` were red, while test, vet and lint stayed green.
Commit `85350b5` reverted the temporary dependency.  The following GitHub
Actions run was green for `govulncheck` and `ci-ok`.  The final tree therefore
contains neither the test dependency nor its call.

### Design answers

**h) Reachability.**  A module-presence result says a vulnerable version is
somewhere in the dependency graph; a reachable result says the application can
call the affected symbol.  The latter prioritises actionable findings and
reduces triage volume, while still requiring judgement for reflection, runtime
configuration and deployment exposure.

**i) Pin the scanner.**  Scanner rules, behaviour and output change over
time.  Pinning `govulncheck@v1.1.4` makes a CI failure reproducible and lets a
reviewer distinguish a code/dependency change from a scanner upgrade.

**j) What it misses.**  `govulncheck` is about reachable Go code.  It does
not scan Debian/Alpine packages and the container base, Dockerfile
misconfiguration, secrets, other language ecosystems, or image-level
libraries.  Those are reasons to keep Trivy image, filesystem and config
scans as separate controls.
