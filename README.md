# Git Resource Provider

A Pulumi provider for declaring and reconciling the state of git repositories, bridged from [UnstoppableMango/terraform-provider-git](https://github.com/UnstoppableMango/terraform-provider-git).

It tracks branches against a base ref and applies a quilt-style ordered patch stack on top of them.

## Installing

**Nothing is published yet.**
No release has been cut, so there is no `v*` tag, no GitHub release, and no package on any registry.
Until the first release lands, none of the following resolve:

- `npm install @unmango/pulumi-git` (not published to npm)
- `pip install pulumi_git` (not published to PyPI)
- `dotnet add package UnMango.Git` (not published to NuGet)
- `go get github.com/UnstoppableMango/pulumi-provider-git/sdk/go/git` (the Go module needs a `v*` tag to be resolvable)

Of those four, only the Go module starts working automatically once a tag exists.
npm, PyPI and NuGet publishing is not wired up at all; the release pipeline attaches the plugin to a GitHub release and stops there.

Once the first tag lands, the intended install path is the GitHub release itself.
`provider/resources.go` sets `PluginDownloadURL` to `github://api.github.com/UnstoppableMango/pulumi-provider-git`, so the Pulumi CLI resolves the plugin from this repository's releases and downloads the tarball for the current platform.
No extra configuration is needed on the consumer side.
Note that this path always goes through the GitHub API rather than a direct download, because Pulumi's fast path is reserved for the `pulumi` organization; consumers behind the unauthenticated API rate limit should set `GITHUB_TOKEN`.

To use the provider today, build it from this repository.
See [Using from Nix](#using-from-nix) below.

## Versioning and releases

The root `VERSION` file is the single source of truth for the provider version.
`Makefile` reads it into `$(VERSION)`, which feeds the `-X .../pkg/version.Version` ldflag and the `VERSION` environment variable that `make tfgen` stamps into the schema, and `flake.nix` reads the same file for the nix build.
Nothing else should hardcode a version.

Bumps are owned by [release-please](https://github.com/googleapis/release-please), driven by [conventional commits](https://www.conventionalcommits.org).
On every push to `main` it maintains a release PR that updates `CHANGELOG.md`, `VERSION`, and the committed generated manifests (`sdk/nodejs/package.json`, `sdk/nodejs/package-lock.json`, `sdk/python/pyproject.toml`, `sdk/dotnet/UnMango.Git.csproj`, and the three `pulumi-plugin.json` files).
`.github/workflows/pr-title.yml` enforces the commit convention on PR titles, since a squashed PR title becomes the commit subject release-please parses.
Merging the release PR tags `v<version>` and publishes a GitHub release.

That tag triggers `.github/workflows/goreleaser.yml`, which cross-compiles the plugin for linux, darwin and windows on amd64 and arm64 and attaches one tarball per platform to the release.
The archive names in `.goreleaser.yml` are a hard contract with Pulumi's plugin resolver, which fetches `pulumi-resource-git-v<version>-<os>-<arch>.tar.gz`; see the comments in that file before changing them.
goreleaser exists alongside the nix build because `systems` is [nix-systems/triplet](https://github.com/nix-systems/triplet) and cannot produce windows or `x86_64-darwin` artifacts.

### Release signing

goreleaser detach-signs the checksum file and uploads the signature as `pulumi-resource-git-v<version>-checksums.txt.sig`.
Only the checksum file is signed, because verifying an archive against a signed list of checksums covers every archive with one signature.

The signing key is `pulumi-provider-git release signing <erik.rasmussen@unmango.dev>`, fingerprint `7135CB2CCB8C92B3F6AB72239E1E52C782BA4D93`.
Its public half is committed at [`release-key.asc`](./release-key.asc) and it expires on 2027-08-23.
This key is specific to this repository and is not the one that signs [terraform-provider-git](https://github.com/UnstoppableMango/terraform-provider-git) releases.

To verify a downloaded archive:

```sh
gpg --import release-key.asc
gpg --verify pulumi-resource-git-v0.0.1-checksums.txt.sig pulumi-resource-git-v0.0.1-checksums.txt
sha256sum --check --ignore-missing pulumi-resource-git-v0.0.1-checksums.txt
```

`gpg --verify` reports `Good signature` alongside a `WARNING: This key is not certified with a trusted signature` line.
That warning is expected and is not a verification failure: it only means you have not signed the release key with your own.
Check the fingerprint above against the one gpg prints, and sign the key locally if you want the warning to go away.

Pulumi's plugin resolver does not check these signatures when it downloads the plugin.
Verification is a manual step for anyone who wants provenance on an artifact.

The provider's version is its own.
It is deliberately independent of the bridged `github.com/UnstoppableMango/terraform-provider-git v0.0.3` pinned in `provider/go.mod`, and the two version lines are not expected to track each other.
Bumping the upstream bridge is an ordinary change to this repository, which release-please then versions like any other.

## Configuration

The following configuration points are available for the `git` provider:

- `git:gitImplementation` - the git backend to use, either `go-git` (default) or `exec`.
- `git:auth` - default authentication used to connect to repositories and hosts, with a `token` field applied when a resource or data source does not set its own `auth.token`.

### Plugin resolution

The SDKs ship with `pluginDownloadURL` set to `github://api.github.com/UnstoppableMango/pulumi-provider-git`, and Pulumi resolves the `pulumi-resource-git` plugin binary in this order:

1. An ambient `pulumi-resource-git` on `PATH` wins. Pulumi logs `warning: using pulumi-resource-git from $PATH at ...` when it takes this route.
2. Otherwise Pulumi downloads the plugin from the `github://` URL, which resolves to this repository's GitHub releases.

That URL is fixed and will not change.
It is part of the default provider URN (`pulumi:providers:git::default_0_0_1_github_/api.github.com/UnstoppableMango/pulumi-provider-git`), so changing or dropping it would give every stack a new default provider and replace every `git:*` resource.

Until a GitHub release exists, only the `PATH` route works.
Put the plugin binary on `PATH` (for example by adding this flake's `packages.default` to a devShell) and Pulumi will pick it up instead of attempting a download.

## Resources

- `git.Branch` - tracks a branch against a `baseRef`, applies an ordered `patches` stack on top of it, and force-pushes the result.
- `git.getRepository` - resolves and verifies an existing repository via `ls-remote`.
- `git.getPatch` - resolves a unified diff and content-addressed ID from inline content, a local file, a GitHub PR/commit, or a GitLab MR/commit.

## Using from Nix

The repo has no published releases yet, so building from this flake is currently the only way to get a working provider plugin and SDK.

### Adding the flake as an input

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    pulumi-provider-git = {
      url = "github:UnstoppableMango/pulumi-provider-git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

`systems` is [nix-systems/triplet](https://github.com/nix-systems/triplet), so outputs exist for `x86_64-linux`, `aarch64-linux` and `aarch64-darwin` only.
A consumer on `x86_64-darwin` gets nothing.

### The provider as an ambient plugin

`packages.<system>.default` is `pulumi-resource-git`.
Put it in your devShell's `packages` and Pulumi picks the plugin up from `PATH`, logging something like `warning: using pulumi-resource-git from $PATH at /nix/store/...`.

```nix
devShells.default = pkgs.mkShell {
  packages = [
    inputs.pulumi-provider-git.packages.${system}.default
  ];
};
```

Pulumi prefers an ambient plugin over the schema's `pluginDownloadURL`, which is what you want here: that URL currently resolves to nothing, because the repo has no releases to download from.

### The Node.js SDK

`packages.<system>.sdk-nodejs` lays the package out at `$out/lib/node_modules/@unmango/pulumi-git`.

That output must be **copied and stripped, not symlinked**.
It bundles its own `node_modules` containing a second `@pulumi/pulumi`, and Node and bun both resolve through a symlink's realpath, so a symlinked SDK would load a different copy of the Pulumi runtime than your program does.
The result is the usual cross-runtime breakage, with two Pulumi runtimes loaded in one process and resources registered against the one the engine isn't talking to.
This is not a subtle preference, a symlink simply does not work.

Copying with `-L` and deleting the nested `node_modules` afterwards leaves the SDK resolving `@pulumi/pulumi` upward into your project's own copy:

```nix
vendorGitSdk = pkgs.writeShellScriptBin "vendor-git-sdk" ''
  set -euo pipefail
  rm -rf node_modules/@unmango/pulumi-git
  mkdir -p node_modules/@unmango
  cp -rL --no-preserve=mode,ownership \
    ${gitProvider.sdk-nodejs}/lib/node_modules/@unmango/pulumi-git \
    node_modules/@unmango/pulumi-git
  rm -rf node_modules/@unmango/pulumi-git/node_modules
'';
```

`gitProvider` there is `inputs.pulumi-provider-git.packages.${system}`.
Run `vendor-git-sdk` from the project root, in `shellHook` or as a build step, before `pulumi up`.

Two gotchas worth knowing before you hit them:

- Do not add `@unmango/pulumi-git` to `package.json`. No package manager can resolve it, and `bun install --frozen-lockfile` fails if the entry is there.
- TypeScript resolves the vendored copy out of `node_modules` fine under `moduleResolution: "bundler"`, with no `paths` entry needed.

### Other outputs

- `packages.<system>.sdk-python` is the Python SDK, built as a `python3.<minor>` package.
- `packages.<system>.sdk-go` is the Go SDK.
- `packages.<system>.sdk-dotnet` is the .NET SDK.
- `packages.<system>.schema` is the generated `schema.json`.

Each is also available under its canonical name, `pulumi-resource-git-sdk-<lang>` and `pulumi-resource-git-schema`.

### Caching

Once CI is authenticated to push to it, these builds will substitute from the `unstoppablemango` [Cachix](https://cachix.org) cache rather than building the provider and every SDK from source.
The cache is not populated yet, but when it is, `cachix use unstoppablemango` (or adding `https://unstoppablemango.cachix.org` to `extra-substituters`) is all a consumer needs.

## Development

Everything is built with [Nix](https://nixos.org) via [pulumi2nix](https://github.com/UnstoppableMango/pulumi2nix).

`flake.nix` declares the provider through `pulumi2nix.flakeModules.default`, so the plugin binary, its schema, and all four SDKs are derived from one `pulumi.terraformBridgeProviders.pulumi-resource-git` declaration and mirrored into `checks`.
The canonical outputs are `pulumi-resource-git`, `pulumi-resource-git-schema` and `pulumi-resource-git-sdk-<lang>`; `schema` and `sdk-<lang>` are kept as short aliases.

```sh
make build     # nix build .#
make check     # nix flake check
make generate  # regenerate schema.json and all four SDKs (run inside `nix develop`)
make fmt       # nix fmt
```

Generated output (`provider/cmd/pulumi-resource-git/schema.json` and `sdk/`) is committed, because the nix build reads the SDK sources out of the git-tracked source tree.

`sdk/python/README.md` is a committed symlink to this file, recreated by `make generate_python` after tfgen writes its own.
PyPI renders it as the package description, and the symlink keeps a README-only edit from leaving the SDK copy stale, which the codegen CI job would otherwise fail on.

### Secrets

The private half of the release signing key and its passphrase live in `secrets/gpg-release-key.enc.yaml`, encrypted with [sops](https://github.com/getsops/sops).
`.sops.yaml` names the recipients that can decrypt it, currently Erik's personal key `B4986C137EB15A0C91FB69FE264283BBFDC491BC`.
`keys/` holds the public half of each recipient, and the devShell runs sops-nix's `sops-import-keys-hook` to import them, so `sops` can encrypt on a machine that has never seen those keys.
Decrypting still requires the matching private key in your own keyring.

The workflow reads the key from the `GPG_PRIVATE_KEY` and `PASSPHRASE` repository secrets, not from `secrets/`.
The encrypted file is the source of truth; the Actions secrets are a copy of it, pushed by hand:

```sh
sops -d --extract '["gpg_private_key"]' secrets/gpg-release-key.enc.yaml | gh secret set GPG_PRIVATE_KEY
sops -d --extract '["passphrase"]' secrets/gpg-release-key.enc.yaml | gh secret set PASSPHRASE
```

To rotate the key, generate a new one, `sops secrets/gpg-release-key.enc.yaml` to replace both fields, re-export `release-key.asc`, and re-run the two commands above.
To add a recipient, drop their public key in `keys/`, add the fingerprint to `.sops.yaml`, then run `sops updatekeys secrets/gpg-release-key.enc.yaml`.
