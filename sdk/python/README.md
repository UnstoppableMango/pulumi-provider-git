# Git Resource Provider

A Pulumi provider for declaring and reconciling the state of git repositories, bridged from [UnstoppableMango/terraform-provider-git](https://github.com/UnstoppableMango/terraform-provider-git).

It tracks branches against a base ref and applies a quilt-style ordered patch stack on top of them.

## Installing

This package is available for several languages/platforms:

### Node.js (JavaScript/TypeScript)

```bash
npm install @unmango/pulumi-git
```

### Python

```bash
pip install pulumi_git
```

### Go

```bash
go get github.com/UnstoppableMango/pulumi-provider-git/sdk/go/git
```

### .NET

```bash
dotnet add package UnMango.Git
```

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

```sh
make build     # nix build .#
make check     # nix flake check
make generate  # regenerate schema.json and all four SDKs (run inside `nix develop`)
make fmt       # nix fmt
```

Generated output (`provider/cmd/pulumi-resource-git/schema.json` and `sdk/`) is committed, because the nix build reads the SDK sources out of the git-tracked source tree.
