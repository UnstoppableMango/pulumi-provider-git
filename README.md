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

The provider's version is its own.
It is deliberately independent of the bridged `github.com/UnstoppableMango/terraform-provider-git v0.0.3` pinned in `provider/go.mod`, and the two version lines are not expected to track each other.
Bumping the upstream bridge is an ordinary change to this repository, which release-please then versions like any other.

## Configuration

The following configuration points are available for the `git` provider:

- `git:gitImplementation` - the git backend to use, either `go-git` (default) or `exec`.
- `git:auth` - default authentication used to connect to repositories and hosts, with a `token` field applied when a resource or data source does not set its own `auth.token`.

## Resources

- `git.Branch` - tracks a branch against a `baseRef`, applies an ordered `patches` stack on top of it, and force-pushes the result.
- `git.getRepository` - resolves and verifies an existing repository via `ls-remote`.
- `git.getPatch` - resolves a unified diff and content-addressed ID from inline content, a local file, a GitHub PR/commit, or a GitLab MR/commit.

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
