# Obrolin: common commands. Run `make help` for the list.
#
# Kubernetes targets work with kind (default) or minikube:
#   make k8s-load CLUSTER=minikube

CLUSTER        ?= kind
KIND_NAME      ?= obrolin
NAMESPACE      := obrolin
BACKEND_IMAGE  := obrolin-backend:local
FRONTEND_IMAGE := obrolin-frontend:local
SERVICE        ?= api

INGRESS_NGINX_VERSION  ?= controller-v1.15.1
METRICS_SERVER_VERSION ?= v0.9.0

KUBECTL := kubectl -n $(NAMESPACE)
BACKEND := cd backend &&

.DEFAULT_GOAL := help
.PHONY: help dev-up dev-down dev-logs dev-seed dev-console dev-reset \
        infra-up api test test-backend test-frontend lint \
        k8s-cluster k8s-ingress k8s-metrics k8s-build k8s-load k8s-deploy k8s-migrate k8s-seed \
        k8s-restart k8s-status k8s-logs k8s-verify k8s-destroy k8s-cluster-delete

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---- Docker Compose (local development) ----------------------------------

.env:
	cp .env.example .env
	sed -i.bak "s/^JWT_SECRET=.*/JWT_SECRET=$$(openssl rand -hex 64)/" .env && rm -f .env.bak
	@echo "Created .env with a random JWT_SECRET"

dev-up: .env ## Build and start the whole stack (http://localhost:5173)
	docker compose up -d --build --wait
	@echo ""
	@echo "  App:            http://localhost:5173  (alice / password123)"
	@echo "  API:            http://localhost:3001/up"
	@echo "  Emails:         http://localhost:3002/letter_opener"

dev-down: ## Stop the stack (data volumes are kept)
	docker compose down

dev-logs: ## Follow logs (SERVICE=api|cable|sidekiq|frontend|...)
	docker compose logs -f $(SERVICE)

dev-seed: ## Load demo data again (idempotent)
	docker compose run --rm api bin/rails db:seed

dev-console: ## Rails console inside the api container
	docker compose exec api bin/rails console

dev-reset: ## Stop the stack and DELETE all local data volumes
	docker compose down -v

# ---- Running on the host (no app containers) -----------------------------

infra-up: .env ## Start only postgres, mongodb and redis
	docker compose up -d --wait postgres mongodb redis

api: ## Run the Rails API on the host (port 3001)
	$(BACKEND) PORT=3001 bin/rails server

# ---- Tests ---------------------------------------------------------------

test: test-backend test-frontend ## Run all tests (needs Ruby + Node on the host and `make infra-up`)

test-backend: ## RSpec
	$(BACKEND) bin/rails db:prepare RAILS_ENV=test >/dev/null && bundle exec rspec

test-frontend: ## Vitest
	cd frontend && npm test

lint: ## RuboCop
	$(BACKEND) bundle exec rubocop

# ---- Kubernetes (kind or minikube) ---------------------------------------

k8s-cluster: ## Create a kind cluster with ingress-nginx and metrics-server
ifeq ($(CLUSTER),kind)
	kind get clusters | grep -qx $(KIND_NAME) || kind create cluster --config k8s/kind-config.yaml
	$(MAKE) k8s-ingress k8s-metrics
else
	minikube status >/dev/null 2>&1 || minikube start --memory=3500 --cpus=4
	minikube addons enable ingress
	minikube addons enable metrics-server
endif

k8s-ingress: ## Install ingress-nginx (kind)
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/$(INGRESS_NGINX_VERSION)/deploy/static/provider/kind/deploy.yaml
	kubectl -n ingress-nginx wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=180s

k8s-metrics: ## Install metrics-server (needed by the HPA)
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/$(METRICS_SERVER_VERSION)/components.yaml
	# kind's kubelets use self-signed certificates.
	kubectl -n kube-system patch deployment metrics-server --type=json \
	  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' || true

k8s-build: ## Build production images
	docker build --target production -t $(BACKEND_IMAGE) backend
	docker build --target production -t $(FRONTEND_IMAGE) frontend

k8s-load: ## Load the images into the cluster
ifeq ($(CLUSTER),kind)
	kind load docker-image $(BACKEND_IMAGE) $(FRONTEND_IMAGE) --name $(KIND_NAME)
else
	minikube image load $(BACKEND_IMAGE)
	minikube image load $(FRONTEND_IMAGE)
endif

k8s-deploy: ## Apply manifests, run migrations, wait for rollouts
	kubectl apply -k k8s/overlays/local
	$(KUBECTL) rollout status statefulset/postgres --timeout=180s
	$(KUBECTL) rollout status statefulset/mongodb --timeout=180s
	$(KUBECTL) rollout status statefulset/redis --timeout=180s
	$(MAKE) k8s-migrate
	$(KUBECTL) rollout status deployment/api --timeout=300s
	$(KUBECTL) rollout status deployment/cable --timeout=300s
	$(KUBECTL) rollout status deployment/sidekiq --timeout=300s
	$(KUBECTL) rollout status deployment/frontend --timeout=120s

k8s-migrate: ## Run the db:migrate Job (deletes the previous run first)
	$(KUBECTL) delete job obrolin-migrate --ignore-not-found
	kubectl apply -k k8s/overlays/local/jobs/migrate
	$(KUBECTL) wait --for=condition=complete job/obrolin-migrate --timeout=300s
	$(KUBECTL) logs job/obrolin-migrate --tail=20

k8s-seed: ## Run the optional seed Job (demo workspace, users, messages)
	$(KUBECTL) delete job obrolin-seed --ignore-not-found
	kubectl apply -k k8s/overlays/local/jobs/seed
	$(KUBECTL) wait --for=condition=complete job/obrolin-seed --timeout=300s
	$(KUBECTL) logs job/obrolin-seed --tail=5

k8s-restart: ## Restart app pods (e.g. after changing the ConfigMap or reloading images)
	$(KUBECTL) rollout restart deployment/api deployment/cable deployment/sidekiq deployment/frontend

k8s-status: ## Show pods, services, ingress, HPA and jobs
	$(KUBECTL) get pods,svc,ingress,hpa,jobs,pvc -o wide

k8s-logs: ## Follow logs of all pods of a component (SERVICE=api|cable|sidekiq|frontend)
	$(KUBECTL) logs -f -l app=$(SERVICE) --all-containers --prefix --max-log-requests 10

k8s-verify: ## Prove WebSocket broadcasts reach clients on every cable pod
	node scripts/verify-cable.mjs http://obrolin.local 8

k8s-destroy: ## Delete the obrolin namespace (all app data in the cluster)
	kubectl delete namespace $(NAMESPACE) --ignore-not-found

k8s-cluster-delete: ## Delete the whole kind cluster
	kind delete cluster --name $(KIND_NAME)
