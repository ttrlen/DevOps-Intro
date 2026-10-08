# Cloudflare quick-tunnel runbook

The bonus uses the exact `linux/amd64` image published by the release workflow.
Do not commit the ephemeral `trycloudflare.com` URL: it changes every time the
tunnel starts.

```bash
docker run --rm --name quicknotes-lab10 -p 8080:8080 \
  -e ADDR=:8080 \
  ghcr.io/ttrlen/devops-intro/quicknotes:v0.1.0

cloudflared tunnel --url http://localhost:8080
```

Copy the `https://<random>.trycloudflare.com` address printed by `cloudflared`.
From a phone on cellular (not the laptop's Wi-Fi), verify:

```bash
curl -v https://<random>.trycloudflare.com/health
```

Measure fifty warmed requests and retain the complete output as evidence:

```bash
hyperfine --warmup 5 --runs 50 \
  'curl --fail --silent --output /dev/null https://<random>.trycloudflare.com/health'
```

Record p50 and p95 from the tool output in `submissions/lab10.md`.
