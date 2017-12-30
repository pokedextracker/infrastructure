MODULES ?= $(shell find * -type d | grep -v '/\.')
ROOT ?= $(shell pwd)

default: lint

lint:
	@terraform fmt -check -diff
	@for module in $(MODULES); do \
		if ls $$module/*tf 1> /dev/null 2>&1; then \
		    cd $$module; \
		    echo "Checking $$module"; \
		    terraform init; \
		    terraform validate 1> /dev/null || exit 1; \
		    cd $(ROOT); \
		fi; \
	done

new:
	@if [ -z "$(NAME)" ]; then \
	  echo "Usage: make new NAME=name"; \
	  exit 1; \
	fi
	@mkdir $(NAME)
	@cp .terraform-version $(NAME)
	@echo 'terraform {' >> $(NAME)/main.tf
	@echo '  backend "s3" {' >> $(NAME)/main.tf
	@echo '    bucket  = "terraform.pokedextracker.com"' >> $(NAME)/main.tf
	@echo '    encrypt = true' >> $(NAME)/main.tf
	@echo '    key     = "$(NAME).tfstate"' >> $(NAME)/main.tf
	@echo '    region  = "us-west-2"' >> $(NAME)/main.tf
	@echo '  }' >> $(NAME)/main.tf
	@echo '}' >> $(NAME)/main.tf
	@echo '' >> $(NAME)/main.tf
	@echo 'provider "aws" {' >> $(NAME)/main.tf
	@echo '  region = "us-west-2"' >> $(NAME)/main.tf
	@echo '}' >> $(NAME)/main.tf
	@touch $(NAME)/outputs.tf

.PHONY: lint
