# Teardown

## Render

In the Render service, open **Settings** and either suspend or delete the
service. If the deploy-hook URL was ever exposed, regenerate it and update the
GitHub Actions secret before re-enabling the service.

## Cloudflare quick tunnel

Stop `cloudflared` with `Ctrl-C`; the ephemeral public URL stops working.
Stop the local container with `Ctrl-C` (or `docker stop quicknotes-lab10` when
it was started detached). No Cloudflare account, named tunnel, or DNS record is
created by a quick tunnel.
