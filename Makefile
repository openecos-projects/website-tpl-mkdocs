MKDOCS_LANG ?= zh
MKDOCS_YML  := mkdocs_$(MKDOCS_LANG).yml

PY_VENV_DIR := .venv
PY_ACTIVATE := $(PY_VENV_DIR)/bin/activate
PY_REQUIREMENTS := tpl/pkg/requirements.txt

NODE_MODULES := ./node_modules

FILE_TAILWIND     := tailwind
FILE_TAILWIND_INT := tpl/theme/assets/stylesheets/$(FILE_TAILWIND).css
FILE_TAILWIND_MIN := tpl/theme/assets/stylesheets/$(FILE_TAILWIND).min.css

FILE_HTML := $(shell find ./src -name "*.html" 2>/dev/null || true)

DOC_SITE := $(READTHEDOCS_OUTPUT)html
WEB_SITE := ./site

.PHONY: check-venv \
        check-node \
        serve-doc  \
        serve-web  \
        build-doc  \
        build-web  \
        gen        \
        gen-news   \
        gen-css    \
        clean      \
        clean-link \
        clean-venv \
        clean-node \
        clean-gen  \
        clean-site \

.PHONY: $(filter check-%, $(MAKECMDGOALS))

$(PY_VENV_DIR)/bin/python:
	@echo "Creating virtual environment..."
	python3 -m venv $(PY_VENV_DIR)
	@echo "Installing requirements..."
	. $(PY_ACTIVATE) && pip install -r $(PY_REQUIREMENTS)

$(NODE_MODULES):
	@echo "Installing nodejs packages..."
	npm install tailwindcss@4.2.2 @tailwindcss/cli@4.2.2 --save-exact

check-venv: $(PY_VENV_DIR)/bin/python

check-node: $(NODE_MODULES)

serve-doc: check-venv gen-css
	@echo "Starting MkDocs server..."
	. $(PY_ACTIVATE) && mkdocs serve -f $(MKDOCS_YML)

serve-web: check-venv gen
	@echo "Starting MkDocs server..."
	. $(PY_ACTIVATE) && mkdocs serve -f $(MKDOCS_YML)

build-doc: check-venv
	@echo "Building documentation..."
	. $(PY_ACTIVATE) && mkdocs build -f $(MKDOCS_YML) --site-dir $(DOC_SITE)
	. $(PY_ACTIVATE) && python3 tpl/script/compress_image.py $(DOC_SITE)

build-web: check-venv
	@echo "Building documentation..."
	. $(PY_ACTIVATE) && mkdocs build -f $(MKDOCS_YML)
	. $(PY_ACTIVATE) && python3 tpl/script/compress_image.py $(WEB_SITE)

gen: gen-news gen-css

gen-news: check-venv
	@echo "Generating news html..."
	. $(PY_ACTIVATE) && python3 tpl/script/generate_news_html.py

gen-css: check-node
	@echo "Generating tailwind css..."
	npx @tailwindcss/cli -i $(FILE_TAILWIND_INT) -o $(FILE_TAILWIND_MIN) -m

clean: clean-venv clean-node clean-gen clean-site

clean-link:
	@echo "Cleaning up repository's link..."
	@for target in $(LINK_TARGET); do \
		if [ -L "$$target/res" ]; then \
			echo "Removing symlink: $$target/res"; \
			rm $$target/res; \
		fi; \
	done

clean-venv:
	@echo "Cleaning up virtual environment..."
	rm -rf .venv

clean-node:
	@echo "Cleaning up nodejs packages..."
	rm -rf $(NODE_MODULES)
	rm -f package.json package-lock.json

clean-gen:
	@echo "Cleaning up dynamic files..."
	rm -f $(FILE_HTML) $(FILE_TAILWIND_MIN)

clean-site:
	@echo "Cleaning up site..."
	rm -rf site
