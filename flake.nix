{
  description = "Reproducible Nix builds for QuickNotes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          buildGo124Module = pkgs.buildGoModule.override { go = pkgs.go_1_24; };
          quicknotes = buildGo124Module {
            pname = "quicknotes";
            version = "1.0.0";
            src = ./app;

            # QuickNotes currently imports only the Go standard library.
            # Use a fixed, explicit null rather than an impure vendor fetch.
            vendorHash = null;

            env = {
              CGO_ENABLED = 0;
            };
            ldflags = [ "-s" "-w" ];
          };
        in
        rec {
          inherit quicknotes;
          default = quicknotes;

          docker = pkgs.dockerTools.buildImage {
            name = "quicknotes";
            tag = "latest";
            # An explicit epoch prevents wall-clock time entering the image config.
            created = "1970-01-01T00:00:01Z";

            copyToRoot = pkgs.buildEnv {
              name = "quicknotes-image-root";
              paths = [ quicknotes ];
              pathsToLink = [ "/bin" ];
            };

            extraCommands = ''
              mkdir -p ./app ./tmp
              cp ${./app/seed.json} ./app/seed.json
              chmod 0444 ./app/seed.json
              chmod 1777 ./tmp
            '';

            config = {
              Entrypoint = [ "/bin/quicknotes" ];
              Env = [
                "DATA_PATH=/tmp/notes.json"
                "SEED_PATH=/app/seed.json"
              ];
              ExposedPorts = { "8080/tcp" = { }; };
              User = "65532:65532";
              WorkingDir = "/app";
            };
          };
        });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = [ pkgs.go_1_24 pkgs.gopls pkgs.golangci-lint ];
          };
        });
    };
}
