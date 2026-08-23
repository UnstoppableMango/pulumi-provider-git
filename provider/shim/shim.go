// Package shim re-exports terraform-provider-git's provider constructor.
//
// The module path is rooted under the upstream module path so that Go's
// internal/ visibility rule allows importing internal/provider from here.
package shim

import (
	tfpf "github.com/hashicorp/terraform-plugin-framework/provider"

	"github.com/UnstoppableMango/terraform-provider-git/internal/provider"
)

func NewProvider() tfpf.Provider {
	return provider.New()
}
