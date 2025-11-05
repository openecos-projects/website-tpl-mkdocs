MKDOCS_LANG ?= zh
MKDOCS_YML  := mkdocs_$(MKDOCS_LANG).yml

PY_VENV_DIR := .venv
PY_ACTIVATE := $(PY_VENV_DIR)/bin/activate
PY_REQUIREMENTS := tpl/pkg/requirements.txt

NODE_MODULES := ./node_modules

FILE_TAILWIND     := tailwind
FILE_TAILWIND_INT := tpl/theme/assets/stylesheets/$(FILE_TAILWIND).css
FILE_TAILWIND_MIN := tpl/theme/assets/stylesheets/$(FILE_TAILWIND).min.css

.PHONY: serve build build-rtd gen-css gen-news clean-link clean-venv clean-node check-venv

$(NODE_MODULES):
	npm install tailwindcss @tailwindcss/cli

$(PY_VENV_DIR)/bin/python:
	@echo "Creating virtual environment..."
	python3 -m venv $(PY_VENV_DIR)
	@echo "Installing requirements..."
	. $(PY_ACTIVATE) && pip install -r $(PY_REQUIREMENTS)

serve: | check-venv
	@echo "Starting MkDocs server..."
	. $(PY_ACTIVATE) && mkdocs serve -f $(MKDOCS_YML)

build: | check-venv
	@echo "Building documentation..."
	. $(PY_ACTIVATE) && mkdocs build -f $(MKDOCS_YML)

build-rtd: | check-venv
	@echo "Building documentation..."
	. $(PY_ACTIVATE) && mkdocs build -f $(MKDOCS_YML) --site-dir $(READTHEDOCS_OUTPUT)/html
	@python3 tpl/script/compress_image.py $(READTHEDOCS_OUTPUT)/html

gen-css: $(NODE_MODULES) $(FILE_TAILWIND_INT)
	npx @tailwindcss/cli -i $(FILE_TAILWIND_INT) -o $(FILE_TAILWIND_MIN) -m

gen-news: | check-venv
	@echo "Generating news html..."
	@python3 tpl/script/generate_news_html.py

clean:
	@echo "Deleting documentation..."
	rm -rf site

clean-link:
	@echo "Cleaning up..."
	@for target in $(LINK_TARGET); do \
		if [ -L "$$target/res" ]; then \
			echo "Removing symlink: $$target/res"; \
			rm $$target/res; \
		fi; \
	done

clean-venv:
	rm -rf .venv

clean-node:
	rm -rf $(NODE_MODULES)
	rm -f package.json package-lock.json

check-venv: $(PY_VENV_DIR)/bin/python
