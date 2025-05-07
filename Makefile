# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

GOOS=$(shell go env GOOS)
ifeq (darwin, $(GOOS))
# Some tools don't use darwin in their download URLs
OS=mac
else
OS=$(GOOS)
endif

GOARCH=$(shell go env GOARCH)
ifeq (amd64, $(GOARCH))
# Some tools don't use amd64 in their download URLs
CPU_ARCH=x86_64
else
CPU_ARCH=$(shell go env GOARCH)
endif

# CONTAINER_TOOL defines the container tool to be used for building images.
# Be aware that the target commands are only tested with Docker which is
# scaffolded by default. However, you might want to replace it to use other
# tools. (i.e. podman)
CONTAINER_TOOL ?= docker

CHART ?=

# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk command is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: build
build:
	npm run compile

.PHONY: test-e2e
test-e2e: chainsaw ## Run the e2e tests against a k8s instance using Kyverno Chainsaw.
	$(CHAINSAW) test ${CHAINSAW_ARGS}

.PHONY: cluster
cluster: kind ctlptl
	@PATH="${LOCALBIN}:$(PATH)" $(CTLPTL) apply -f hack/kind.yaml
	$(CONTAINER_TOOL) run \
		--rm --interactive --tty --detach \
		--name cloud-provider-kind \
		--network kind \
		-v /var/run/docker.sock:/var/run/docker.sock \
		registry.k8s.io/cloud-provider-kind/cloud-controller-manager:${CLOUD_PROVIDER_KIND_VERSION} || true
	cd hack && $(HELM) install jspolicy jspolicy \
		--namespace jspolicy \
		--create-namespace \
		--repo https://charts.loft.sh \
		--version $(JSPOLICY_VERSION)

.PHONY: cluster-reset
cluster-reset: kind ctlptl
	$(CONTAINER_TOOL) kill cloud-provider-kind
	@PATH="${LOCALBIN}:$(PATH)" $(CTLPTL) delete -f hack/kind.yaml

##@ Dependencies

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool URLs
CHAINSAW_URL ?= https://github.com/kyverno/chainsaw/releases/download/$(CHAINSAW_VERSION)/chainsaw_$(GOOS)_$(GOARCH).tar.gz
CTLPTL_URL   ?= https://github.com/tilt-dev/ctlptl/releases/download/$(CTLPTL_VERSION)/ctlptl.$(patsubst v%,%,$(CTLPTL_VERSION)).$(OS).$(CPU_ARCH).tar.gz
HELM_URL     ?= https://get.helm.sh/helm-$(GOOS)-$(GOARCH).tar.gz
KIND_URL     ?= https://github.com/kubernetes-sigs/kind/releases/download/$(KIND_VERSION)/kind-$(GOOS)-$(GOARCH)
KUBECTL_URL  ?= https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/$(GOOS)/$(GOARCH)/kubectl

## Tool Versions
# renovate: datasource=github-tags depName=kyverno/chainsaw
CHAINSAW_VERSION ?= v0.2.12

# renovate: datasource=docker depName=registry.k8s.io/cloud-provider-kind/cloud-controller-manager
CLOUD_PROVIDER_KIND_VERSION ?= v0.6.0

# renovate: datasource=github-tags depName=tilt-dev/ctlptl
CTLPTL_VERSION ?= v0.8.40

# renovate: datasource=github-tags depName=helm/helm
HELM_VERSION ?= v3.17.3

# renovate: datasource=helm depName=jspolicy registryUrl=https://charts.loft.sh
JSPOLICY_VERSION ?= 0.2.2

# renovate: datasource=github-tags depName=kubernetes-sigs/kind
KIND_VERSION ?= v0.27.0

# renovate: datasource=github-tags depName=kubernetes/kubernetes
KUBECTL_VERSION ?= v1.32.2

## Tool Binaries
CHAINSAW ?= $(LOCALBIN)/chainsaw-$(CHAINSAW_VERSION)
CTLPTL   ?= $(LOCALBIN)/ctlptl-$(CTLPTL_VERSION)
HELM     ?= $(LOCALBIN)/helm-$(HELM_VERSION)
KIND     ?= $(LOCALBIN)/kind-$(KIND_VERSION)
KUBECTL  ?= $(LOCALBIN)/kubectl-$(KUBECTL_VERSION)

.PHONY: chainsaw
chainsaw: $(CHAINSAW) ## Download chainsaw locally if necessary.
$(CHAINSAW): $(LOCALBIN)
	$(call download-and-install,$(CHAINSAW_URL),$(CHAINSAW),"chainsaw")
	ln -sf $(CHAINSAW) $(LOCALBIN)/chainsaw

.PHONY: ctlptl
ctlptl: $(CTLPTL) ## Download ctlptl locally if necessary.
$(CTLPTL): $(LOCALBIN)
	$(call download-and-install,$(CTLPTL_URL),$(CTLPTL),"ctlptl")
	ln -sf $(CTLPTL) $(LOCALBIN)/ctlptl

.PHONY: helm
helm: $(HELM) ## Download helm locally if necessary.
$(HELM): $(LOCALBIN)
	$(call download-and-install,$(HELM_URL),$(HELM),"helm")
	ln -sf $(HELM) $(LOCALBIN)/helm

.PHONY: kind
kind: $(KIND) ## Download kind locally if necessary.
$(KIND): $(LOCALBIN)
	$(call download-and-install,$(KIND_URL),$(KIND))
	ln -sf $(KIND) $(LOCALBIN)/kind

.PHONY: kubectl
kubectl: $(KUBECTL) ## Download kubectl locally if necessary.
$(KUBECTL): $(LOCALBIN)
	$(call download-and-install,$(KUBECTL_URL),$(KUBECTL))
	ln -sf $(KUBECTL) $(LOCALBIN)/kubectl

# download-and-install:
# $(1) = download URL
# $(2) = destination path (where you want the binary)
# $(3) = filename inside tar.gz (or leave empty for raw binary)
define download-and-install
	if [[ "$(1)" == *.tar.gz ]] || [[ "$(1)" == *.tgz ]]; then \
		TMP_DIR=$$(mktemp -d) && \
		curl --fail -sL "$(1)" | tar -xz -C "$$TMP_DIR" && \
		BINARY=$$(find "$$TMP_DIR" -type f -perm -u+x -name "*$(notdir $(3))*" | head -1 || find "$$TMP_DIR" -type f -perm -u+x | head -1) && \
		mv "$$BINARY" "$(2)" && \
		chmod +x "$(2)" && \
		rm -rf "$$TMP_DIR"; \
	else \
		curl --fail -sL -o "$(2)" "$(1)" && \
		chmod +x "$(2)"; \
	fi
endef
