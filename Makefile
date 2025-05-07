# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
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

.PHONY: deploy
deploy:
	kubectl apply -f ./policies

.PHONY: undeploy
undeploy:
	kubectl delete -f ./policies

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
	helm install jspolicy jspolicy \
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

## Tool Binaries
CHAINSAW ?= $(LOCALBIN)/chainsaw
CTLPTL   ?= $(LOCALBIN)/ctlptl
KIND     ?= $(LOCALBIN)/kind

## Tool Versions
# renovate: datasource=github-tags depName=kyverno/chainsaw
CHAINSAW_VERSION ?= v0.2.12

# renovate: datasource=docker depName=registry.k8s.io/cloud-provider-kind/cloud-controller-manager
CLOUD_PROVIDER_KIND_VERSION ?= v0.6.0

# renovate: datasource=github-tags depName=tilt-dev/ctlptl
CTLPTL_VERSION ?= v0.8.40

# renovate: datasource=helm depName=jspolicy registryUrl=https://charts.loft.sh
JSPOLICY_VERSION ?= 0.2.0

# renovate: datasource=github-tags depName=kubernetes-sigs/kind
KIND_VERSION ?= v0.27.0

.PHONY: chainsaw
chainsaw: $(CHAINSAW)-$(CHAINSAW_VERSION) ## Download chainsaw locally if necessary.
$(CHAINSAW)-$(CHAINSAW_VERSION): $(LOCALBIN)
	$(call go-install-tool,$(CHAINSAW),github.com/kyverno/chainsaw,$(CHAINSAW_VERSION))

.PHONY: ctlptl
ctlptl: $(CTLPTL)-$(CTLPTL_VERSION) ## Download ctlptl locally if necessary.
$(CTLPTL)-$(CTLPTL_VERSION): $(LOCALBIN)
	$(call go-install-tool,$(CTLPTL),github.com/tilt-dev/ctlptl/cmd/ctlptl,$(CTLPTL_VERSION))

.PHONY: kind
kind: $(KIND)-$(KIND_VERSION) ## Download kind locally if necessary.
$(KIND)-$(KIND_VERSION): $(LOCALBIN)
	$(call go-install-tool,$(KIND),sigs.k8s.io/kind,$(KIND_VERSION))

# go-install-tool will 'go install' any package with custom target and name of binary, if it doesn't exist
# $1 - target path with name of binary
# $2 - package url which can be installed
# $3 - specific version of package
define go-install-tool
@[ -f "$(1)-$(3)" ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
rm -f $(1) || true ;\
GOBIN=$(LOCALBIN) go install $${package} ;\
mv $(1) $(1)-$(3) ;\
} ;\
ln -sf $(1)-$(3) $(1)
endef
