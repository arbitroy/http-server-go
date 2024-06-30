GO := go

DIRS_TO_CLEAN :=
FILES_TO_CLEAN :=

ifeq ($(origin GO), undefined)
  GO := $(shell where go 2>nul)
endif
ifeq ($(GO),)
  $(error Could not find 'go' in path. Please install go, or if already installed either add it to your path or set GO to point to its directory)
endif

pkgs = $(shell $(GO) list ./... 2>nul | findstr /v /c:"/vendor/" /c:"/pkg/swagger/" 2>nul)
pkgDirs = $(shell $(GO) list -f {{.Dir}} ./... 2>nul | findstr /v /c:"/vendor/" /c:"/pkg/swagger/" 2>nul)
DIR_OUT := $(TEMP)

GOLANGCI := $(shell where golangci-lint 2>nul)
WWHRD := $(shell where wwhrd 2>nul)

GO_EXCLUDE := /vendor/|.pb.go|.gen.go
GO_FILES_CMD := forfiles /S /M *.go /C "cmd /C if @isdir==FALSE findstr /v /c:\"$(GO_EXCLUDE)\" @path 2>nul"

#-------------------------
# Final targets
#-------------------------
.PHONY: dev

## Execute development pipeline
dev: license generate format lint.fast build

#-------------------------
# Download libraries and tools
#-------------------------
.PHONY: get.tools

## Retrieve tools packages
get.tools:
	@echo "Retrieving tools packages"
	@echo "License checker"
	go get -u github.com/frapposelli/wwhrd
	@echo "Linter"
	go get -u github.com/golangci/golangci-lint/cmd/golangci-lint

#-------------------------
# Code generation
#-------------------------
.PHONY: generate

## Generate go code
generate:
	@echo "==> generating go code"
	$(GO) generate $(pkgs)

#-------------------------
# Checks
#-------------------------
.PHONY: format license lint.fast lint.full

check: format license lint.full

## Apply code format, import reorganization and code simplification on source code
format:
	@echo "==> formatting code"
	$(GO) fmt $(pkgs)
	@echo "==> clean imports"
	goimports -w $(pkgDirs)
	@echo "==> simplify code"
	gofmt -s -w $(pkgDirs)

## Check external license usage
license:
ifndef WWHRD
	$(error "Please install wwhrd! make get-tools")
endif
	@echo "==> license check"
	wwhrd check

## Launch linter
lint.fast:
ifndef GOLANGCI
	$(error "Please install golangci! make get-tools")
endif
	@echo "==> linters (fast)"
	golangci-lint run -v --fast $(pkgDirs)

## Validate code
lint.full:
ifndef GOLANGCI
	$(error "Please install golangci! make get-tools")
endif
	@echo "==> linters (slow)"
	golangci-lint run -v $(pkgDirs)

#-------------------------
# Build artefacts
#-------------------------
.PHONY: build

## Build all binaries
build:
	$(GO) build -o bin\http-go-server internal\main.go

## Compress all binaries
pack:
	@echo ">> packing all binaries"
	upx -7 -qq bin\*

#-------------------------
# Target: depend
#-------------------------
.PHONY: depend depend.tidy depend.verify depend.vendor depend.update depend.cleanlock depend.update.full

## Use go modules
depend: depend.tidy depend.verify depend.vendor

depend.tidy:
	@echo "==> Running dependency cleanup"
	$(GO) mod tidy -v

depend.verify:
	@echo "==> Verifying dependencies"
	$(GO) mod verify

depend.vendor:
	@echo "==> Freezing dependencies"
	$(GO) mod vendor

depend.update:
	@echo "==> Update go modules"
	$(GO) get -u -v

depend.update.full: depend.cleanlock depend.update

#-------------------------
# Target: clean
#-------------------------
.PHONY: clean clean.go

## Clean build files
clean: clean.go
	del /Q $(DIRS_TO_CLEAN)
	del /Q $(FILES_TO_CLEAN)

clean.go: ; $(info cleaning...)
	$(eval GO_CLEAN_FLAGS := -i -r)
	$(GO) clean $(GO_CLEAN_FLAGS)

#-------------------------
# Target: help
#-------------------------

TARGET_MAX_CHAR_NUM = 20
## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  make <target>'
	@echo ''
	@echo 'Targets:'
	@awk "/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, \":\")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf \"  %-$(TARGET_MAX_CHAR_NUM)s %s\n\", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }" $(MAKEFILE_LIST)

#-------------------------
# Target: swagger.validate
#-------------------------
.PHONY: swagger.validate

swagger.validate:
	swagger validate pkg\swagger\swagger.yml

#-------------------------
# Target: swagger.doc
#-------------------------
.PHONY: swagger.doc

swagger.doc:
	docker run -i yousan/swagger-yaml-to-html < pkg\swagger\swagger.yml > doc\index.html
