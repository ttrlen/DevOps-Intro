# Render configuration

## Chosen source

This is an **Existing Image** web service, not a Git-backed service:

```text
ghcr.io/ttrlen/devops-intro/quicknotes:v0.1.0
```

The image is built, scanned and published once by the release workflow.  Render
then pulls that exact, immutable release tag, rather than rebuilding different
dependencies from the repository.  The release workflow passes the next tag as
the URL-encoded `imgURL` query parameter to the secret Render deploy hook.

## Dashboard settings

| Setting | Value |
|---|---|
| Service type | Web Service / Existing Image |
| Instance type | **Free** |
| Region | Frankfurt |
| Image URL | `ghcr.io/ttrlen/devops-intro/quicknotes:v0.1.0` |
| Health check path | `/health` |
| Render-provided port | `PORT=10000` |
| Environment variable configured by us | `ADDR=:10000` |
| Persistent disk | None (intentionally, to demonstrate ephemeral notes) |

Render injects `PORT=10000` for this service.  QuickNotes reads `ADDR`, so
`ADDR=:10000` makes the application bind to the port Render routes to from its
first boot. `DATA_PATH` and `SEED_PATH` retain the image defaults
(`/data/notes.json` and `/app/seed.json`).

After creating the service, copy **Settings → Deploy Hook** into the GitHub
repository Actions secret named `RENDER_DEPLOY_HOOK_URL`. It is deliberately
not written to this repository.

The hook step is intentionally skipped (not failed) until that secret exists.
This lets the first tag, `v0.1.0`, publish the image that Render needs when the
service is created. After the secret is added, create `v0.1.1`; its green
release run both publishes `:v0.1.1` and calls the hook with that immutable
tag. A hook request can change only the image tag, not its host, owner or name.

## Evidence to add after deployment

Replace the placeholders in `submissions/lab10.md` only with observed values:

- Render public URL;
- deploy-log line showing `quicknotes listening on :10000` (and absence of
  `New primary port detected`);
- Actions run URL which pushed the tag and invoked the hook.
