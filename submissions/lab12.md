# Lab 12 — WebAssembly Containers: QuickNotes Moscow-Time Endpoint

## Scope and reproducibility

The Spin component is in [wasm/moscow-time](../wasm/moscow-time/) and the
standalone WASI CLI module is in [wasm-cli](../wasm-cli/). I scaffolded the
component from the Spin 3.4 template, rather than creating a manifest from an
old WAGI tutorial:

~~~
mkdir -p wasm && cd wasm
spin new -t http-go moscow-time --accept-defaults
~~~

The generated sources were changed only to implement GET /time. See
[main.go](../wasm/moscow-time/main.go),
[spin.toml](../wasm/moscow-time/spin.toml), and
[go.mod](../wasm/moscow-time/go.mod). The manifest routes exactly /time,
sets allowed_outbound_hosts to an empty list, and keeps the template build
command with TinyGo wasip1 and -buildmode=c-shared.

| Tool | Pinned version |
|---|---|
| Spin | 3.4.0 |
| TinyGo | 0.41.0 (Go 1.26.0, LLVM 20.1.1) |
| Spin Go SDK | v2.2.1 |
| Wasmtime | 48.0.2 |
| Hyperfine | 1.20.0 |
| Docker | 29.8.0 |

The generated main.wasm artifacts are intentionally not committed. Each
directory ignores its output and rebuilds it with the documented commands.

## Task 1 — Spin HTTP component

Build, run, and verification:

~~~
$ cd wasm/moscow-time
$ spin build
Building component moscow-time with tinygo build -target=wasip1 -buildmode=c-shared -no-debug -o main.wasm .
Finished building all Spin components

$ stat -c '%n %s bytes' main.wasm
main.wasm 370137 bytes

$ spin up
Serving http://127.0.0.1:3000
Available Routes:
  moscow-time: http://127.0.0.1:3000/time

$ curl -s http://127.0.0.1:3000/time | python3 -m json.tool
{
    "unix": 1791647939,
    "iso": "2026-10-10T18:58:59+03:00",
    "hour_minute": "18:58"
}
~~~

The handler returns Content-Type: application/json. Moscow uses a fixed MSK
UTC+3 zone instead of time.LoadLocation("Europe/Moscow"), so the RFC3339
offset is truthful and no time-zone database is required. A method other than
GET receives HTTP 405.

### Design questions

**a. Browser WASM vs server WASM.** GOOS=js GOARCH=wasm targets a browser
embedding: it needs JavaScript glue and has browser APIs. TinyGo wasip1
targets the WASI ABI instead; it has no DOM, JavaScript host, or browser event
loop. In return it is suitable for a server-side WASI host, has an explicit
capability boundary, and produces a compact portable artifact.

**b. Why -buildmode=c-shared?** The Spin Go SDK provides exported adapter
symbols through which Spin delivers a wasi-http request to the handler.
-buildmode=c-shared makes TinyGo emit the host-visible ABI that adapter
expects. A regular CLI build has a different entrypoint/export shape, so the
HTTP host cannot invoke the handler (typically producing HTTP 500).

**c. Empty outbound-host capability.** Spin grants capabilities per component.
With an empty allowed-outbound-hosts list, this component cannot make outbound
HTTP connections even if later code tries; it has no ambient network authority.
Docker --network none similarly disconnects a container at the network layer,
but it is a runtime-wide Linux namespace setting. Spin stores a precise,
per-component allow-list in the manifest.

**d. TinyGo standard-library gap.** TinyGo does not fully implement upstream
Go's standard library. In this lab, time.LoadLocation would require time-zone
data that is not embedded by default, so the endpoint uses a fixed UTC+3
location. Reflection-heavy dynamic encoding such as encoding a map[string]any
is also a poor fit; the JSON is formed with fmt and %q instead.

## Task 2 — Spin versus Lab 6 Docker

### Test rig and method

- Host: x86_64 AMD Ryzen 5 5600H (6 cores / 12 threads), Linux
  6.6.87.2-microsoft-standard-WSL2.
- Docker baseline: existing Lab 6 quicknotes:lab6 image,
  sha256:048444581cbc6ed447cd9b4cf1c15f62a2c971d4c5a1fde1fa8a7d502bc63615.
- Warm test: Hyperfine 1.20.0, 5 warmups and 50 runs, against Docker GET
  /health on port 8080 and Spin GET /time on port 3000. The local proxy was
  bypassed for loopback traffic.
- Cold test: five samples each. The clock started immediately before spin up
  or docker run and stopped at the first successful HTTP response. Docker used
  a separate temporary container on port 18080, so the existing Lab 6
  container was never stopped.
- The artifact was already loaded locally. These are restart cold-starts, not
  registry-download times. p50 and p95 use linear interpolation over
  Hyperfine's exported 50 samples; cold-start p50 is the median of five.

| Dimension | Lab 6 Docker | Lab 12 WASM/Spin |
|---|---:|---:|
| Artifact size | 23,032,733 bytes (21.96 MiB; Docker displays 23 MB) | 370,137 bytes (361.5 KiB) |
| Cold start p50 | 656.199 ms | 68.966 ms |
| Warm latency p50 | 8.636 ms | 9.595 ms |
| Warm latency p95 | 9.402 ms | 10.415 ms |

Raw cold-start samples, in milliseconds:

| Runtime | Samples |
|---|---|
| Docker | 690.225, 657.797, 650.390, 656.199, 650.685 |
| Spin | 97.174, 84.346, 68.966, 66.883, 68.089 |

Exact warm benchmark:

~~~
$ hyperfine --warmup 5 --runs 50   'curl --noproxy "*" --fail --silent --output /dev/null http://127.0.0.1:8080/health'   'curl --noproxy "*" --fail --silent --output /dev/null http://127.0.0.1:3000/time'

Benchmark 1: .../health
  Time (mean ± σ): 8.7 ms ± 0.5 ms    [50 runs]
Benchmark 2: .../time
  Time (mean ± σ): 9.6 ms ± 0.5 ms    [50 runs]
~~~

### Design questions

**e. Cold-start cost.** On a truly cold Docker host, pulling and extracting
layers can dominate, followed by daemon work, cgroups/namespaces, and process
startup. The local image was cached, so the Docker restart measurements mostly
include the latter work plus QuickNotes startup. Spin loads the manifest and
component, then Wasmtime loads/compiles the module and instantiates the
wasi-http component. This is substantially lighter, as the p50s show.

**f. Workload fit.** WASM is well suited to short stateless high-fan-out
workloads: edge request handlers, untrusted plugins, and multi-tenant
functions. Docker remains a better fit for long-running stateful services,
arbitrary OS packages, mature database clients, broad syscall access, and
teams dependent on OCI tooling and debugging.

**g. Multi-tenant safety.** A module has no ambient host filesystem or network
authority. Without a pre-opened directory it cannot read /etc/passwd, SSH
keys, or another tenant's volume, making an arbitrary-file-read or
path-traversal bug far less useful. Linux containers share a kernel and still
depend on correct namespace and mount configuration.

## Bonus — standalone WASI CLI module

[wasm-cli/main.go](../wasm-cli/main.go) reads REQUEST_METHOD and PATH_INFO,
accepts only GET /time, and writes the same JSON to stdout. It has no Spin SDK
dependency.

~~~
$ cd wasm-cli
$ tinygo build -o main.wasm -target=wasi -no-debug ./main.go
$ wasmtime run --env REQUEST_METHOD=GET --env PATH_INFO=/time main.wasm
{"unix":1791647894,"iso":"2026-10-10T18:58:14+03:00","hour_minute":"18:58"}
~~~

The CLI module is 195,915 bytes (191.3 KiB). Five direct cached wasmtime run
invocations measured 19.203, 17.813, 17.617, 17.396, and 19.802 ms, so its p50
is 17.813 ms. Each is deliberately a new process and module instance. The
Spin artifact is 361.5 KiB and its HTTP-server restart p50 is 68.966 ms; once
running it serves persistently (9.595 ms warm p50). These are different
execution models, not a claim of endpoint-for-endpoint equivalence.

### Design questions

**h. Why bare wasmtime run cannot execute the Spin component.** The Spin
artifact exports a wasi-http handler ABI for an HTTP host to call; it is not a
WASI CLI program with a _start entrypoint. wasmtime run expects the latter,
while Spin (or wasmtime serve) supplies the HTTP trigger bindings.

**i. What Spin adds over Wasmtime.** Spin embeds Wasmtime but adds the
manifest, route matching, wasi-http request/response adaptation, component
lifecycle and pooling behavior, component logging, and capability policy
enforcement such as allowed_outbound_hosts.

**j. When each model fits.** Per-invocation wasmtime run fits a batch filter
or one-shot CI transformation where stdin/stdout is the interface. Spin's
persistent wasi-http server fits an API or edge function that receives many
HTTP requests, where routing and avoiding a process startup per request are
valuable.
