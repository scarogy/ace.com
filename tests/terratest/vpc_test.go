package test
import ("testing"; "github.com/gruntwork-io/terratest/modules/terraform")
func TestVpcModuleInit(t *testing.T) {
  opts := &terraform.Options{ TerraformDir: "../../infra/terraform/modules/vpc" }
  terraform.Init(t, opts)
}
