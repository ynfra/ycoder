# Include variables
-include .env
export

.PHONY: push

push:
	coder templates push vibestack -d . \
		--variable gitlab_token="$$GITLAB_TOKEN" \
		--variable gitlab_host="$$GITLAB_HOST" \
		--variable github_token="$$GITHUB_TOKEN" \
		--variable composer_auth="$$COMPOSER_AUTH_B64" \
		--variable docker_registry_host="$${DOCKER_REGISTRY_HOST}" \
		--variable docker_registry_user="$$DOCKER_REGISTRY_USER" \
		--variable docker_registry_token="$$DOCKER_REGISTRY_TOKEN" \
		--variable xclaude_auth_token="$$XCLAUDE_AUTH_TOKEN" \
		--variable xclaude_base_url="$${XCLAUDE_BASE_URL}" \
		--variable xclaude_model="$${XCLAUDE_MODEL:-cx/gpt-5.6-terra}" \
		--variable xclaude_small_model="$${XCLAUDE_SMALL_MODEL:-cx/gpt-5.6-terra}" \
		--variable xclaude_effort="$${XCLAUDE_EFFORT:-high}" \
		--variable xclaude_permission_mode="$${XCLAUDE_PERMISSION_MODE:-true}" \
		--variable xclaude_bypass="$${XCLAUDE_BYPASS:-false}" \
		-y
