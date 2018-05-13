terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "budget.tfstate"
    region  = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_budgets_budget" "pokedextracker" {
  name              = "monthly-pokedextracker-budget"
  budget_type       = "COST"
  limit_amount      = "70"
  limit_unit        = "USD"
  time_period_start = "2017-07-01_00:00"
  time_unit         = "MONTHLY"
}
