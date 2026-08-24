# The root VERSION file is the single source of truth. release-please rewrites
# it on every bump, and flake.nix reads the same file.
VERSION := $(shell tr -d '[:space:]' < VERSION)
LDFLAGS := -X github.com/UnstoppableMango/pulumi-provider-git/provider/pkg/version.Version=v$(VERSION)
TFGEN := ./bin/pulumi-tfgen-git

# Codegen targets need the pulumi CLI and its language plugins, so run them
# from `nix develop`. Their output is committed: the nix build reads the
# schema and every SDK out of the git-tracked source tree.
FAKE_GO_MOD = printf 'module fake_$(1)_module // Exclude this directory from Go tools\n\ngo 1.17\n' > sdk/$(1)/go.mod

build:
	nix build .#

update:
	nix flake update

check lint:
	nix flake check

format fmt:
	nix fmt

generate: tfgen generate_nodejs generate_python generate_go generate_dotnet

$(TFGEN): provider/*.go provider/go.* provider/cmd/pulumi-tfgen-git/*.go
	cd provider && go build -ldflags "$(LDFLAGS)" -o ../$(TFGEN) ./cmd/pulumi-tfgen-git

# Run from provider/ so the bridge can `go list -m` the upstream module and
# pull its docs and examples into the schema. The SDK targets below must run
# from the repo root instead, since they read provider/cmd/.../schema.json
# relative to the working directory.
tfgen: $(TFGEN)
	cd provider && ../$(TFGEN) schema --out ./cmd/pulumi-resource-git
	cd provider && VERSION=v$(VERSION) go generate ./cmd/pulumi-resource-git/...

generate_nodejs: $(TFGEN)
	$(TFGEN) nodejs --out sdk/nodejs
	$(call FAKE_GO_MOD,nodejs)
	cd sdk/nodejs && npm install --package-lock-only --no-audit --no-fund

generate_python: $(TFGEN)
	$(TFGEN) python --out sdk/python
	$(call FAKE_GO_MOD,python)
	# A symlink, not a copy: pyproject.toml points `readme` at this path and
	# PyPI renders the root README, but a copy silently goes stale whenever
	# README.md is edited alone, which the codegen CI job then fails on. tfgen
	# writes its own README.md here first, so this replaces it every run.
	ln -sfn ../../README.md sdk/python/README.md

generate_go: $(TFGEN)
	$(TFGEN) go --out sdk/go
	cd sdk && go mod tidy

generate_dotnet: $(TFGEN)
	$(TFGEN) dotnet --out sdk/dotnet
	$(call FAKE_GO_MOD,dotnet)

# Regenerates nix/dotnet-deps.json, the nuget lock buildDotnetModule consumes.
# Needed whenever the .NET SDK's package references change.
nuget_deps:
	nix build .#sdk-dotnet.passthru.fetch-deps
	./result nix/dotnet-deps.json

.PHONY: build update check lint format fmt generate tfgen \
	generate_nodejs generate_python generate_go generate_dotnet nuget_deps
