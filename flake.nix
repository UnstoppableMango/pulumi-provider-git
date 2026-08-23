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

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem =
        { lib, pkgs, ... }:
        let
          pulumi2nix = inputs.pulumi2nix.lib { inherit pkgs; };

          version = "0.0.1";
          goModule = "github.com/UnstoppableMango/pulumi-provider-git";

          provider = pulumi2nix.mkTerraformBridgeProvider {
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

            # The default python pname/importsCheck are derived from `repo`,
            # which doesn't match the `pulumi_git` package tfgen emits.
            pythonArgs = {
              pname = "pulumi-git";
              pythonImportsCheck = [ "pulumi_git" ];
            };

            nodejsArgs = {
              lockFile = ./sdk/nodejs/package-lock.json;
              npmDepsHash = "sha256-qOnUtP7XSLCqCIynQ6dB37AhIy+8Aus2DyNZK5HBdRc=";
            };

            goArgs.vendorHash = "sha256-3m92XeNznUgT2pBgcngUqOn8e0cirwc0Jo47alif6Dw=";

            dotnetArgs.nugetDeps = ./nix/dotnet-deps.json;

            meta = {
              description = "A Pulumi provider for declaring and reconciling the state of git repositories";
              mainProgram = "pulumi-resource-git";
              homepage = "https://github.com/UnstoppableMango/pulumi-provider-git";
              license = lib.licenses.mit;
              maintainers = [ ];
            };
          };

          packages = {
            default = provider;
            pulumi-resource-git = provider;
            schema = provider.passthru.schema;
          }
          // lib.mapAttrs' (lang: sdk: lib.nameValuePair "sdk-${lang}" sdk) provider.passthru.sdks;
        in
        {
          inherit packages;
          checks = packages;

          devShells.default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              dotnet-sdk
              gnumake
              go
              nixfmt
              nodejs
              pulumi
              pulumiPackages.pulumi-go
              pulumiPackages.pulumi-nodejs
              pulumiPackages.pulumi-python
              python3
              inputs.pulumi2nix.packages.${pkgs.stdenv.hostPlatform.system}.pulumi-language-dotnet
            ];
          };

          treefmt.programs = {
            gofmt.enable = true;
            nixfmt.enable = true;
          };
        };
    };
}
