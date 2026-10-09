# Lab 11 — Reproducible Builds of QuickNotes with Nix

Branch: `feature/lab11`

## Task 1 — reproducible Go binary

The repository-root [`flake.nix`](../flake.nix) pins `nixpkgs` to the
`nixos-25.11` release line and [`flake.lock`](../flake.lock) records the exact
immutable revision. The package is implemented with `buildGoModule` overridden
to Go 1.24, matching `app/go.mod`'s minimum language version. It builds
`app/` with `CGO_ENABLED=0`, `-trimpath`, and `-ldflags=-s -w`.

`vendorHash = null` is intentional and fixed: QuickNotes currently has no
third-party Go modules, so there is no vendor tree to hash. If a dependency is
added, Nix will require the resulting fixed-output vendor hash before it can
build.

Run the following in two clean clones or fresh Nix environments:

```console
$ nix build .#quicknotes
$ nix-store --query --hash "$(readlink result)"
# Record environment A's output here after the build.

$ nix build .#quicknotes
$ nix-store --query --hash "$(readlink result)"
# Record environment B's identical output here after the independent build.
```

Runtime check:

```console
$ ./result/bin/quicknotes &
$ curl --fail http://127.0.0.1:8080/health
```

### Design answers

**a.** A normal `go build` can encode absolute source paths, build IDs,
timestamps, toolchain versions, and the module/vendor resolution state. The
flake removes those moving inputs: `-trimpath` removes local paths, the pinned
toolchain and lockfile fix the inputs, and Nix builds in a controlled store.

**b.** `vendorHash` is the fixed-output hash of the vendored dependency source
tree prepared for the Go build. A non-null placeholder causes Nix to fail and
print the required hash. `vendorHash = null` is valid only when the project has
no external dependencies; otherwise it disables the vendoring integrity check
and is rejected by `buildGoModule`.

**c.** `flake.lock` resolves the symbolic nixpkgs input to an exact commit and
its content hash. It is therefore the record of the entire package set used by
the build. Deleting it lets a later evaluation resolve `nixos-25.11` again,
possibly to a different revision and different compiler/build inputs.

**d.** `buildGoModule` is nixpkgs' general Go module builder: it constructs and
hashes the dependency/vendor phase, then builds the program. `buildGoApplication`
is an older wrapper with a narrower interface. `buildGoModule` is chosen here
because it is the standard current builder and exposes the fixed vendor hash.

## Task 2 — deterministic image

`packages.<system>.docker` uses `pkgs.dockerTools.buildImage`, so it creates a
loadable image archive without invoking Docker. Its `created` field is fixed to
the Unix epoch, the QuickNotes binary is the exec-form entrypoint, `8080/tcp`
is exposed, and the service runs as UID/GID `65532`. The application writes
its runtime note file to the standard sticky `/tmp` directory (mode `1777`) and
reads the read-only `/app/seed.json`.

Verification commands, run in two independent environments:

```console
$ nix build .#docker
$ sha256sum result
c7f77abb9e55c2dfcda7999aee3a640b45d7b65428447ed190dc5722b84f0f53  result

$ nix build .#docker
$ sha256sum result
c7f77abb9e55c2dfcda7999aee3a640b45d7b65428447ed190dc5722b84f0f53  result

$ docker load < result
$ docker run --rm -p 8080:8080 quicknotes:latest
```

The two matching values above were produced in two independently created
`nixos/nix:2.30.3` containers, each with its own empty Nix store. The archive
size was 5.3 MiB. The Lab 6 control experiment is:

```console
$ docker build --no-cache -t qn-lab6:run1 ./app
$ docker build --no-cache -t qn-lab6:run2 ./app
$ docker images --no-trunc qn-lab6
# Paste both distinct image IDs and the size comparison here after running it.
```

### Design answers

**e.** Traditional Docker builds normally introduce wall-clock timestamps in
image/config/layer metadata; base-image tag resolution and unpinned build tools
can add further moving inputs. `dockerTools.buildImage` constructs the archive
from fixed store paths and the explicit fixed `created` value.

**f.** A signature proves that a particular party signed a particular opaque
artifact. A reproducible image additionally lets an auditor independently
rebuild the declared source and verify that it is exactly that artifact.

**g.** Nix requires a Nix installation, Nix expressions, pinned dependency
hashes, and familiarity with its store model. Docker remains the default
because Dockerfiles and registries are ubiquitous, easy to introduce, and fit
existing developer and deployment workflows.

## Bonus — CI proof

[`nix-repro.yml`](../.github/workflows/nix-repro.yml) starts two independent
Ubuntu runners in parallel. Each pins the Nix installer action by full commit
SHA, builds `.#docker`, and exposes the archive SHA-256 as a job output. A
third job compares the two values and fails on any mismatch.

The first green run is [GitHub Actions run #37992635226](https://github.com/ttrlen/DevOps-Intro/actions/runs/37992635226).
Its comparison job reported:

```text
environment A: c7f77abb9e55c2dfcda7999aee3a640b45d7b65428447ed190dc5722b84f0f53
environment B: c7f77abb9e55c2dfcda7999aee3a640b45d7b65428447ed190dc5722b84f0f53
```

The deliberately-broken red run URL and its mismatch excerpt will be recorded
after the one-run CI demonstration below, before restoring the workflow.

### Design answers

**h.** A laptop proof shares one local Nix store, operating environment, cache,
and often undocumented configuration. CI records that clean ephemeral runners
can independently recreate the same artifact, which is the auditable claim.

**i.** Two builds in one job can share a store, downloaded artifacts, temporary
state, and host configuration; it can therefore miss contamination or
machine-specific inputs. Parallel fresh runners isolate those variables.

**j.** Build timestamps can leak through generated files, compiler/linker
metadata, archive headers, and image configuration. The flake prevents the
relevant image-config timestamp by explicitly setting `created`; Nix store
inputs and `-trimpath` constrain the build-side inputs. `dockerTools` creates
its archive deterministically from those fixed inputs.
