SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules


# Override PWD so that it's always based on the location of the file and **NOT**
# based on where the shell is when calling `make`. This is useful if `make`
# is called like `make -C <some path>`
PWD := $(realpath $(dir $(abspath $(firstword $(MAKEFILE_LIST)))))

WORKTREE_ROOT := $(shell git rev-parse --show-toplevel 2> /dev/null)

# Using backticks instead of $(shell) to run evulation only when it's accessed
# https://unix.stackexchange.com/a/687206
py = $$(if [ -d $(PWD)/'.venv' ]; then echo $(PWD)/".venv/bin/python3"; else echo "python3"; fi)
pip = $(py) -m pip


.PHONY: help
help: ## Display this message
	@grep -E \
		'^[a-zA-Z\.\$$/]+.*:.*?##\s.*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-38s\033[0m %s\n", $$1, $$2}'



# PY_PATHS := list with paths to packages
pypath := python3 -c 'import sys, pathlib as p; print(":".join([str(p.Path(x).resolve()) for x in sys.argv[1:]]))'

# Base tailwind config
define _TW_CONF
module.exports = {
  content: ["./**/*.{html,js}"],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
  ]
}
endef


# Base tailwind CSS
define _TW_CSS
@tailwind base;
@tailwind components;
@tailwind utilities;
endef


bin/tailwind: ## Download tailwind binary
	curl -SsL https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-macos-arm64 -o bin/tailwind
	chmod +x bin/tailwind


files/output.css: export TW_CONF = $(_TW_CONF)
files/output.css: export TW_CSS = $(_TW_CSS)
files/output.css: bin/tailwind
	@echo "$$TW_CONF" > tailwind.conf.js
	@echo "$$TW_CSS" > input.css
	./bin/tailwind --minify --input input.css --config tailwind.conf.js --output ./files/output.css
	rm tailwind.conf.js
	rm input.css

files/htmx.js:
	curl -SsL https://unpkg.com/htmx.org -o files/htmx.js

files/alpine.js:
	curl -SsL https://unpkg.com/alpinejs -o files/alpine.js

files/pico.css:
	curl -SsL https://unpkg.com/@picocss/pico@latest/css/pico.min.css -o files/pico.css


.PHONY: assets
assets: files/htmx.js files/alpine.js files/pico.css ## Download static assets


.venv: requirements.in  ## Create .venv, compile requirements.txt and install requirements.txt
	micromamba run --name=f python3 -m venv .venv
	$(pip) install -U pip setuptools
	$(pip) install -U wheel build pip-tools
	$(py) -m piptools compile --resolver=backtracking --generate-hashes --output-file requirements.txt requirements.in
	$(py) -m piptools sync
	touch .venv


requirements.txt: requirements.in | .venv  ## Compile requirements.txt from requirements.in
	$(py) -m piptools compile --resolver=backtracking --generate-hashes --output-file requirements.txt requirements.in


.PHONY: upgrade-requirements
upgrade-requirements: requirements.in  ## Upgrade pip, setuptools, wheel, pip-tools and requirements.txt
	$(pip) install -U pip setuptools
	$(pip) install -U wheel build pip-tools
	$(py) -m piptools compile --resolver=backtracking --upgrade --generate-hashes --output-file requirements.txt requirements.in
	$(py) -m piptools sync
	touch .venv


.PHONY: ttt
# ttt: export PYTHONPATH = $(shell $(pypath) $(PY_PATHS)):$${PYTHONPATH:-}
ttt:
	@cat <<<"$$TW_CONF"


