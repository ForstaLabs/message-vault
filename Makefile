default: build

PACKAGES := node_modules/.packages.build
SEMANTIC := semantic/dist/.semantic.build
GRUNT := dist/.grunt.build
LINT := .lint.pass
BUILD := dist/build.json
DOCKER_DB_NAME := vault_db$(shell pwd | sed 's/\//_/g')
APP_NAME := $(shell node -p "require('./package.json').name")
APP_VERSION := $(shell node -p "require('./package.json').version")

export NO_MINIFY ?= 1

packages: $(PACKAGES)
semantic: $(SEMANTIC)
grunt: $(GRUNT)

NPATH := $(shell pwd)/node_modules/.bin
SRC := $(shell find client html images stylesheets server -type f)

PG_SITE := https://get.enterprisedb.com/postgresql/
PG_BIN_LINUX := postgresql-10.3-3-linux-x64-binaries.tar.gz
PG_BIN_WINDOWS := postgresql-10.3-3-windows-x64-binaries.zip
PG_BIN_DARWIN := postgresql-10.3-3-osx-binaries.zip

ELECTRON_IGNORES := \
	--ignore '^/.buildpacks' \
	--ignore '^/.github' \
	--ignore '^/.gitignore' \
	--ignore '^/.lint.pass' \
	--ignore '^/.npmrc' \
	--ignore '^/.sass-cache' \
	--ignore '^/.slugignore' \
	--ignore '^/Gemfile.*' \
	--ignore '^/Gruntfile.js.json' \
	--ignore '^/Makefile' \
	--ignore '^/Procfile' \
	--ignore '^/client' \
	--ignore '^/builds' \
	--ignore '^/html' \
	--ignore '^/images' \
	--ignore '^/references' \
	--ignore '^/semantic' \
	--ignore '^/semantic.json' \
	--ignore '^/stylesheets' \
	--ignore '^/node_modules/semantic-ui' \
	--ignore '^/electron/downloads' \
	--ignore '^/electron/pgdata'


########################################################
# Building & cleaning targets
########################################################

ifneq ($(SKIP_PACKAGES),1)
$(PACKAGES): package.json
	npm install
	touch $@
else
$(PACKAGES):
	touch $@
endif

$(SEMANTIC): $(shell find semantic/src -type f)
	cd semantic && $(NPATH)/gulp build
	touch $@

ifneq ($(NODE_ENV),production)
$(LINT): $(SRC)
	$(NPATH)/eslint client server
	touch $@
else
$(LINT):
	touch $@
endif

$(GRUNT): $(PACKAGES) $(SEMANTIC) Gruntfile.js $(SRC) $(LINT) Makefile
	$(NPATH)/grunt default
	touch $@

$(BUILD): $(GRUNT) Makefile
	echo '{"git_commit": "$(or $(SOURCE_VERSION),$(shell git rev-parse HEAD))"}' > $@

clean:
	rm -rf $(PACKAGES) $(SEMANTIC) $(GRUNT) dist

realclean: clean
	rm -rf node_modules components

build: $(BUILD)

lint: $(LINT)

docker-db-run:
	if docker inspect $(DOCKER_DB_NAME) >/dev/null 2>&1; then \
		echo "Starting existing database"; \
		docker start --attach $(DOCKER_DB_NAME); \
	else \
		echo "Creating NEW database"; \
		docker run -p 5432:5432 --name $(DOCKER_DB_NAME) postgres:10; \
	fi

docker-db-clean:
	docker kill $(DOCKER_DB_NAME) 2>/dev/null || exit 0
	docker rm -f $(DOCKER_DB_NAME) 2>/dev/null || exit 0

electron-clean:
	rm -rf electron/pgdata

electron-win:
	mkdir -p electron/downloads/win
	rm -rf electron/downloads/win/*
	cd electron/downloads; wget -qc $(PG_SITE)$(PG_BIN_WINDOWS)
	cd electron/downloads/win; unzip -q ../$(PG_BIN_WINDOWS)
	cd electron/downloads/win/pgsql && rm -rf doc pgAdmin\ 4 StackBuilder
	$(NPATH)/electron-builder --win nsis --publish never

electron-mac:
	mkdir -p electron/downloads/mac
	rm -rf electron/downloads/mac/*
	cd electron/downloads; wget -qc $(PG_SITE)$(PG_BIN_DARWIN)
	cd electron/downloads/mac; unzip -q ../$(PG_BIN_DARWIN)
	cd electron/downloads/mac/pgsql; rm -rf doc pgAdmin\ 4.app stackbuilder
	$(NPATH)/electron-builder --mac zip --publish never

electron-linux:
	mkdir -p electron/downloads/linux
	rm -rf electron/downloads/linux/*
	cd electron/downloads; wget -qc $(PG_SITE)$(PG_BIN_LINUX)
	cd electron/downloads/linux; tar zxf ../$(PG_BIN_LINUX)
	cd electron/downloads/linux/pgsql; rm -rf doc pgAdmin\ 4 stackbuilder
	$(NPATH)/electron-builder --linux AppImage --publish never


########################################################
# Runtime-only targets
########################################################
watch:
	$(NPATH)/grunt watch

run: $(BUILD)
	npm start

forcerun:
	npm start

electron-run: $(BUILD)
	$(NPATH)/electron .


.PHONY: electron
