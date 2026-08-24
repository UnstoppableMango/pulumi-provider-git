{
  description = "A Pulumi provider for git, bridged from terraform-provider-git";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:nix-systems/triplet";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    pulumi2nix = {
      url = "github:UnstoppableMango/pulumi2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Only the devShell consumes this. There is no NixOS host here, so none of
    # sops-nix's modules are imported; what it provides is sops-import-keys-hook,
    # which seeds a throwaway GNUPGHOME from keys/ (see devShells.default) so
    # `sops` can encrypt for every recipient in .sops.yaml without the operator
    # having imported their public keys by hand.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.pulumi2nix.flakeModules.default
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        {
          config,
          inputs',
          lib,
          pkgs,
          pulumi2nix,
          ...
        }:
        let
          # The root VERSION file is the single source of truth, shared with the
          # Makefile. It is git-tracked, so reading it stays pure-eval safe.
          version = lib.strings.trim (builtins.readFile ./VERSION);
          goModule = "github.com/UnstoppableMango/pulumi-provider-git";

          # The flake module names `packages.pulumi-resource-git` after the
          # declaration below, and flattens its `passthru.schema`/`passthru.sdks`
          # into `packages.pulumi-resource-git-{schema,sdk-<lang>}`.
          provider = config.pulumi.packages.pulumi-resource-git;
        in
        {
          pulumi.terraformBridgeProviders.pulumi-resource-git = {
            # Build from this checkout rather than a fetch of a pushed tag, so
            # the provider, its schema and every SDK come from the working tree.
            # Only git-tracked files are visible, which is why the generated
            # schema.json and sdk/ trees are committed.
            src = inputs.self;
            repo = "pulumi-provider-git";
            inherit version;

            cmdGen = "pulumi-tfgen-git";
            cmdRes = "pulumi-resource-git";
            vendorHash = "sha256-9Cz3X57TokfHCUtMEEDhVQ0eHgTsSgweoZwLhd/94mQ=";
            extraLdflags = [ "-X ${goModule}/provider/pkg/version.Version=v${version}" ];

            # `sdkDrift.languages` is deliberately unset. It re-runs
            # `pulumi-tfgen-git <lang>` and diffs the result over the committed
            # `sdk/<lang>`, which is exactly the check this repo wants, but the
            # bridge version here delegates codegen to `pulumi package gen-sdk`
            # and the check derivation has neither the pulumi CLI nor the
            # language hosts on PATH. Upstream issue #61.

            sdks = {
              # Every SDK opts out of src narrowing: `narrowSdkSrc` crashes in
              # pure eval on a `src` that is a flake input. Upstream issue #60,
              # which has the one-line fix. Drop these four lines once it lands
              # and the SDKs stop rebuilding on unrelated file changes.
              nodejs = {
                narrowSrc = false;
                lockFile = ./sdk/nodejs/package-lock.json;
                # Covers the lock file itself, so the version in it is part of
                # the hash and every release bump invalidates this line.
                # `make npm_deps` rewrites it.
                npmDepsHash = "sha256-qOnUtP7XSLCqCIynQ6dB37AhIy+8Aus2DyNZK5HBdRc=";
              };

              python.narrowSrc = false;

              go = {
                narrowSrc = false;
                vendorHash = "sha256-3m92XeNznUgT2pBgcngUqOn8e0cirwc0Jo47alif6Dw=";
              };

              dotnet = {
                narrowSrc = false;
                nugetDeps = ./nix/dotnet-deps.json;
              };
            };

            meta = {
              description = "A Pulumi provider for declaring and reconciling the state of git repositories";
              mainProgram = "pulumi-resource-git";
              homepage = "https://github.com/UnstoppableMango/pulumi-provider-git";
              license = lib.licenses.mit;
              maintainers = [ ];
            };
          };

          # Short aliases for the module's canonical output names. `checks` comes
          # from the module, and covers the same derivations under those names.
          packages = {
            default = provider;
            schema = provider.passthru.schema;
          }
          // lib.mapAttrs' (lang: sdk: lib.nameValuePair "sdk-${lang}" sdk) provider.passthru.sdks;

          devShells.default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              dotnet-sdk
              gnumake
              gnupg
              go
              nixfmt
              nodejs
              prefetch-npm-deps
              pulumi
              pulumiPackages.pulumi-go
              pulumiPackages.pulumi-nodejs
              pulumiPackages.pulumi-python
              python3
              sops
              pulumi2nix.pulumiLanguageDotnet
            ];

            # Runs at shell entry and `gpg --import`s every .asc under keys/ into
            # the ambient keyring, so `sops` can encrypt to the .sops.yaml
            # recipients on a machine that has never seen their public keys.
            # `sopsCreateGPGHome` is deliberately unset: with it, the hook would
            # redirect GNUPGHOME to .git/gnupg, and decrypting would stop working
            # because the private keys live in the operator's own ~/.gnupg.
            nativeBuildInputs = [ inputs'.sops-nix.packages.sops-import-keys-hook ];
            sopsPGPKeyDirs = [ "./keys" ];
          };

          treefmt.programs = {
            gofmt.enable = true;
            nixfmt.enable = true;
          };
        };
    };
}
