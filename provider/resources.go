package git

import (
	"path"

	// Allow embedding bridge-metadata.json in the provider.
	_ "embed"

	pf "github.com/pulumi/pulumi-terraform-bridge/v3/pkg/pf/tfbridge"
	"github.com/pulumi/pulumi-terraform-bridge/v3/pkg/tfbridge"
	"github.com/pulumi/pulumi-terraform-bridge/v3/pkg/tfbridge/tokens"

	"github.com/UnstoppableMango/terraform-provider-git/shim"

	"github.com/UnstoppableMango/pulumi-provider-git/provider/pkg/version"
)

const (
	// mainPkg is the package name used by the nodejs and python registries.
	mainPkg = "git"
	// mainMod is the module every resource and data source lands in.
	mainMod = "index"
)

//go:embed cmd/pulumi-resource-git/bridge-metadata.json
var metadata []byte

// Provider returns the schema and metadata that bridge terraform-provider-git
// into a Pulumi provider.
func Provider() tfbridge.ProviderInfo {
	prov := tfbridge.ProviderInfo{
		P:                 pf.ShimProvider(shim.NewProvider()),
		Name:              mainPkg,
		Version:           version.Version,
		DisplayName:       "Git",
		Publisher:         "UnstoppableMango",
		Description:       "A Pulumi package for declaring and reconciling the state of git repositories.",
		Keywords:          []string{"git", "patch", "category/utility"},
		License:           "MIT",
		Homepage:          "https://github.com/UnstoppableMango/pulumi-provider-git",
		Repository:        "https://github.com/UnstoppableMango/pulumi-provider-git",
		GitHubOrg:         "UnstoppableMango",
		PluginDownloadURL: "github://api.github.com/UnstoppableMango/pulumi-provider-git",
		MetadataInfo:      tfbridge.NewProviderMetadata(metadata),

		JavaScript: &tfbridge.JavaScriptInfo{
			PackageName: "@unmango/pulumi-git",
			// RespectSchemaVersion ensures the SDK is generated linking to the correct version of the provider.
			RespectSchemaVersion: true,
		},
		Python: &tfbridge.PythonInfo{
			PackageName:          "pulumi_git",
			RespectSchemaVersion: true,
			// Enable modern PyProject support in the generated Python SDK.
			PyProject: struct{ Enabled bool }{true},
		},
		Golang: &tfbridge.GolangInfo{
			ImportBasePath: path.Join(
				"github.com/UnstoppableMango/pulumi-provider-git/sdk/",
				tfbridge.GetModuleMajorVersion(version.Version),
				"go",
				mainPkg,
			),
			GenerateResourceContainerTypes: true,
			GenerateExtraInputTypes:        true,
			RespectSchemaVersion:           true,
		},
		CSharp: &tfbridge.CSharpInfo{
			RootNamespace:        "UnMango",
			RespectSchemaVersion: true,
			// Use a wildcard import so NuGet will prefer the latest possible version.
			PackageReferences: map[string]string{
				"Pulumi": "3.*",
			},
		},
	}

	prov.MustComputeTokens(tokens.SingleModule("git_", mainMod,
		tokens.MakeStandard(mainPkg)))

	prov.MustApplyAutoAliases()
	prov.SetAutonaming(255, "-")

	return prov
}
