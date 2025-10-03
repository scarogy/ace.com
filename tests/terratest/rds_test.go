package test
import ("testing"; "github.com/gruntwork-io/terratest/modules/terraform")
func TestRdsModuleInit(t *testing.T) {
  opts := &terraform.Options{ TerraformDir: "../../infra/terraform/modules/rds" }
  terraform.Init(t, opts)
}
