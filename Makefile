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
	@echo "[init] creating virtual environment..."
	python3 -m venv $(PY_VENV_DIR)
	@echo "[init] installing requirements..."
	. $(PY_ACTIVATE) && pip install -r $(PY_REQUIREMENTS)

$(NODE_MODULES):
	@echo "[init] installing nodejs packages..."
	npm install tailwindcss@4.2.2 @tailwindcss/cli@4.2.2 sharp@0.34.5 --save-exact

check-venv: $(PY_VENV_DIR)/bin/python

check-node: $(NODE_MODULES)

serve-doc: check-venv gen-css
	@echo "[serve] starting MkDocs server..."
	. $(PY_ACTIVATE) && mkdocs serve -f $(MKDOCS_YML)

serve-web: check-venv gen
	@echo "[serve] starting MkDocs server..."
	. $(PY_ACTIVATE) && mkdocs serve -f $(MKDOCS_YML)

build-doc: check-venv
	@echo "[build] building documentation..."
	. $(PY_ACTIVATE) && mkdocs build -f $(MKDOCS_YML) --site-dir $(DOC_SITE)
# 	node tpl/script/compress_image.js $(DOC_SITE)
	. $(PY_ACTIVATE) && python3 tpl/script/compress_image.py $(DOC_SITE)

build-web: check-venv
	@echo "[build] building documentation..."
	. $(PY_ACTIVATE) && mkdocs build -f $(MKDOCS_YML)
	node tpl/script/compress_image.js $(WEB_SITE)

gen: gen-news gen-css

gen-news: check-venv
	@echo "[gen] generating news html..."
	. $(PY_ACTIVATE) && python3 tpl/script/generate_news_html.py

gen-css: check-node
	@echo "[gen] generating tailwind css..."
	npx @tailwindcss/cli -i $(FILE_TAILWIND_INT) -o $(FILE_TAILWIND_MIN) -m

clean: clean-venv clean-node clean-gen clean-site

clean-link:
	@echo "[clean] deleting softlink..."
	@for target in $(LINK_TARGET); do  \
		if [ -d "$$target/res" ]; then \
			rm -rf $$target/res;       \
		fi;                            \
	done
	@echo "[clean] done!"

clean-venv:
	@echo "[clean] deleting virtual environment..."
	rm -rf .venv
	@echo "[clean] done!"

clean-node:
	@echo "[clean] deleting nodejs packages..."
	rm -rf $(NODE_MODULES)
	rm -f package.json package-lock.json
	@echo "[clean] done!"

clean-gen:
	@echo "[clean] deleting dynamic files..."
	rm -f $(FILE_HTML) $(FILE_TAILWIND_MIN)
	@echo "[clean] done!"

clean-site:
	@echo "[clean] deleting site..."
	rm -rf site
	@echo "[clean] done!"
