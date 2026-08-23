package main

import (
	"github.com/pulumi/pulumi-terraform-bridge/v3/pkg/pf/tfgen"

	git "github.com/UnstoppableMango/pulumi-provider-git/provider"
)

func main() {
	tfgen.Main("git", git.Provider())
}
