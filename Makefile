ifneq (,$(findstring /tpl, $(CURDIR)))
    $(error [fail] please cd to "doc" or "web" dir before running make)
endif

MKDOCS_LANG     ?= zh
MKDOCS_YML      := mkdocs_$(MKDOCS_LANG).yml
MKDOCS_ADDR     ?= localhost:8000

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

DOC_DEPLOY_DEST ?=

.PHONY: check-venv     \
        check-node     \
        check-mkdocs   \
        install-mkdocs \
        serve-doc      \
        serve-web      \
        build-doc      \
        build-web      \
        deploy-doc     \
        gen-doc        \
        gen-web        \
        gen-news       \
        gen-css        \
        gen-webp       \
        clean          \
        clean-link     \
        clean-venv     \
        clean-node     \
        clean-gen      \
        clean-site     \

.PHONY: $(filter check-%, $(MAKECMDGOALS))

$(PY_VENV_DIR)/bin/python:
	@echo "[init] creating virtual environment..."
	python3 -m venv $(PY_VENV_DIR)
	@echo "[init] installing requirements..."
	. $(PY_ACTIVATE) && pip install -r $(PY_REQUIREMENTS)

$(NODE_MODULES):
	@echo "[init] installing nodejs packages..."
	npm install tailwindcss@4.2.2 @tailwindcss/cli@4.2.2 sharp@0.34.5 --save-exact
	npm pkg set type=module

check-venv: $(PY_VENV_DIR)/bin/python

check-node: $(NODE_MODULES)

check-mkdocs: check-venv
	@echo "[check] checking MkDocs packages..."
	@. $(PY_ACTIVATE) && missing="" && seen=" "; \
	while IFS= read -r line || [ -n "$$line" ]; do \
		line="$${line%%#*}"; \
		name="$$(printf '%s' "$$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$$//; s/\[.*//; s/==.*//; s/[[:space:]]+$$//')"; \
		if [ -z "$$name" ]; then continue; fi; \
		case "$$seen" in *" $$name "*) continue ;; esac; \
		seen="$$seen$$name "; \
		if ! pip show "$$name" >/dev/null 2>&1; then missing="$$missing $$name"; fi; \
	done < "$(PY_REQUIREMENTS)"; \
	if [ -n "$$missing" ]; then \
		echo "[check] missing:$$missing"; \
		echo "[install] installing MkDocs packages..."; \
		pip install -r $(PY_REQUIREMENTS) || exit 1; \
	fi; \
	echo "[check] $$(mkdocs --version)"; \
	pip show mkdocs-material | awk '/^Version:/ {print "[check] Material for MkDocs " $$2}'; \
	echo "[check] MkDocs packages are installed"

install-mkdocs: check-venv
	@echo "[install] installing MkDocs packages..."
	@. $(PY_ACTIVATE) && pip install -r $(PY_REQUIREMENTS)
	@echo "[install] done!"

serve-doc: check-mkdocs gen-doc
	@echo "[serve] starting MkDocs server..."
	. $(PY_ACTIVATE) && mkdocs serve -f $(MKDOCS_YML) --dev-addr $(MKDOCS_ADDR)

serve-web: check-venv gen-web
	@echo "[serve] starting MkDocs server..."
	. $(PY_ACTIVATE) && mkdocs serve -f $(MKDOCS_YML) --dev-addr $(MKDOCS_ADDR)

build-doc: check-venv
	@echo "[build] building documentation..."
	. $(PY_ACTIVATE) && mkdocs build -f $(MKDOCS_YML) --site-dir $(DOC_SITE)

build-web: check-venv
	@echo "[build] building documentation..."
	. $(PY_ACTIVATE) && mkdocs build -f $(MKDOCS_YML)

deploy-doc: check-mkdocs gen-doc
	@if [ -z "$(DOC_DEPLOY_DEST)" ]; then \
		echo "[deploy] DOC_DEPLOY_DEST is empty"; \
		echo "[deploy] make deploy-doc DOC_DEPLOY_DEST=user@host:/var/www/ics55-docs/"; \
		exit 1; \
	fi
	@echo "[deploy] building Chinese and English sites..."
	$(MAKE) build-doc MKDOCS_LANG=zh DOC_SITE=site
	$(MAKE) build-doc MKDOCS_LANG=en DOC_SITE=site/en
	@echo "[deploy] copying site/ to $(DOC_DEPLOY_DEST)..."
	rsync -a --delete site/ "$(DOC_DEPLOY_DEST)"
	@echo "[deploy] done!"

gen-doc: gen-css gen-webp

gen-web: gen-news gen-css gen-webp

gen-news: check-venv
	@echo "[gen] generating news html..."
	. $(PY_ACTIVATE) && python3 tpl/script/generate_news_html.py

gen-css: check-node
	@echo "[gen] generating tailwind css..."
	npx @tailwindcss/cli -i $(FILE_TAILWIND_INT) -o $(FILE_TAILWIND_MIN) -m

gen-webp:
	@echo "[gen] generating webp images..."
	node tpl/script/compress_image.js ./res

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
