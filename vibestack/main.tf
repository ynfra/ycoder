# =============================================================================
# vibestack — Coder template
#
# ToC
#   1. Providers
#   2. Locals
#   3. Variables
#   4. Parameters
#   5. Data sources
#   6. Agent
#   7. Env
#   8. Apps
#   9. Scripts
#  10. Docker
# =============================================================================

# =============================================================================
# ### 1. Providers
# =============================================================================

terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

# =============================================================================
# ### 2. Locals
# =============================================================================

locals {
  # YYYY-MM-DD-vN; bump to force an image re-pull.
  template_version = "2026-08-09-v1"

  image = "dockette/coder:fx"

  username       = data.coder_workspace_owner.me.name
  workspace_id   = data.coder_workspace.me.id
  workspace_name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  dind_hostname  = "${local.workspace_name}-dind"
}

# =============================================================================
# ### 3. Variables
# =============================================================================

variable "docker_socket" {
  description = "(Optional) Docker socket URI"
  type        = string
  default     = ""
}

variable "gitlab_token" {
  description = "GitLab PAT → GITLAB_TOKEN"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gitlab_host" {
  description = "GitLab host → GITLAB_HOST"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_token" {
  description = "GitHub token → GITHUB_TOKEN (gh CLI)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "composer_auth" {
  description = "Base64 Composer auth JSON → COMPOSER_AUTH (base64 avoids quote issues in --variable)"
  type        = string
  sensitive   = true
  default     = ""
}

# Docker registry login (DOCKER_REGISTRY_* avoids clashing with Docker's DOCKER_*).
variable "docker_registry_host" {
  description = "Registry host → DOCKER_REGISTRY_HOST"
  type        = string
  default     = ""
}

variable "docker_registry_user" {
  description = "Registry user → DOCKER_REGISTRY_USER"
  type        = string
  default     = ""
}

variable "docker_registry_token" {
  description = "Registry token → DOCKER_REGISTRY_TOKEN"
  type        = string
  sensitive   = true
  default     = ""
}

# Alternate claude gateway as XCLAUDE_* (won't overwrite ANTHROPIC_*). See xclaude in startup.sh.
variable "xclaude_base_url" {
  description = "xclaude gateway URL → XCLAUDE_BASE_URL"
  type        = string
  default     = ""
}

variable "xclaude_auth_token" {
  description = "xclaude token → XCLAUDE_AUTH_TOKEN (gates all XCLAUDE_* env injection)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "xclaude_model" {
  description = "xclaude primary model → XCLAUDE_MODEL"
  type        = string
  default     = ""
}

variable "xclaude_small_model" {
  description = "xclaude small/fast model → XCLAUDE_SMALL_MODEL"
  type        = string
  default     = ""
}

variable "xclaude_effort" {
  description = "xclaude reasoning effort → XCLAUDE_EFFORT"
  type        = string
  default     = "high"
}

variable "xclaude_permission_mode" {
  description = "If true, xclaude uses --permission-mode auto (ignored when xclaude_bypass is true)"
  type        = string
  default     = "true"
}

variable "xclaude_bypass" {
  description = "If true, xclaude uses --dangerously-skip-permissions"
  type        = string
  default     = "false"
}

# =============================================================================
# ### 4. Parameters
# =============================================================================

data "coder_parameter" "git_repo" {
  name         = "git_repo"
  display_name = "Git repository"
  description  = "Optional: clone into ~/code on first start. Blank = none."
  type         = "string"
  default      = ""
  mutable      = true
  order        = 1
}

# =============================================================================
# ### 5. Data sources
# =============================================================================

provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# =============================================================================
# ### 6. Agent
# =============================================================================

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # Shared startup.sh, then optional startup.custom.sh (or just `summary`).
  startup_script = join("\n", [
    file("${path.module}/startup.sh"),
    fileexists("${path.module}/startup.custom.sh") ? file("${path.module}/startup.custom.sh") : "summary",
  ])

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    script       = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

# =============================================================================
# ### 7. Env
# =============================================================================

resource "coder_env" "git_author_name" {
  agent_id = coder_agent.main.id
  name     = "GIT_AUTHOR_NAME"
  value    = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
}

resource "coder_env" "git_author_email" {
  agent_id = coder_agent.main.id
  name     = "GIT_AUTHOR_EMAIL"
  value    = data.coder_workspace_owner.me.email
  count    = data.coder_workspace_owner.me.email != "" ? 1 : 0
}

resource "coder_env" "git_committer_name" {
  agent_id = coder_agent.main.id
  name     = "GIT_COMMITTER_NAME"
  value    = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
}

resource "coder_env" "git_committer_email" {
  agent_id = coder_agent.main.id
  name     = "GIT_COMMITTER_EMAIL"
  value    = data.coder_workspace_owner.me.email
  count    = data.coder_workspace_owner.me.email != "" ? 1 : 0
}

# Coder-managed SSH for git; accept-new skips host-key prompts.
resource "coder_env" "git_ssh_command" {
  agent_id = coder_agent.main.id
  name     = "GIT_SSH_COMMAND"
  value    = "coder gitssh -- -o StrictHostKeyChecking=accept-new"
}

resource "coder_env" "git_repo" {
  count    = data.coder_parameter.git_repo.value != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "GIT_REPO"
  value    = data.coder_parameter.git_repo.value
}

# --- tokens (only inject when set) ---

resource "coder_env" "gitlab_token" {
  count    = var.gitlab_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "GITLAB_TOKEN"
  value    = var.gitlab_token
}

resource "coder_env" "gitlab_host" {
  count    = var.gitlab_host != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "GITLAB_HOST"
  value    = var.gitlab_host
}

resource "coder_env" "github_token" {
  count    = var.github_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "GITHUB_TOKEN"
  value    = var.github_token
}

resource "coder_env" "composer_auth" {
  count    = var.composer_auth != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "COMPOSER_AUTH"
  value    = base64decode(var.composer_auth)
}

# --- docker registry (startup.sh docker login; only when token is set) ---

resource "coder_env" "docker_registry_host" {
  count    = var.docker_registry_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "DOCKER_REGISTRY_HOST"
  value    = var.docker_registry_host
}

resource "coder_env" "docker_registry_user" {
  count    = var.docker_registry_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "DOCKER_REGISTRY_USER"
  value    = var.docker_registry_user
}

resource "coder_env" "docker_registry_token" {
  count    = var.docker_registry_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "DOCKER_REGISTRY_TOKEN"
  value    = var.docker_registry_token
}

# --- xclaude ---


resource "coder_env" "xclaude_base_url" {
  count    = var.xclaude_auth_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "XCLAUDE_BASE_URL"
  value    = var.xclaude_base_url
}

resource "coder_env" "xclaude_auth_token" {
  count    = var.xclaude_auth_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "XCLAUDE_AUTH_TOKEN"
  value    = var.xclaude_auth_token
}

resource "coder_env" "xclaude_model" {
  count    = var.xclaude_auth_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "XCLAUDE_MODEL"
  value    = var.xclaude_model
}

resource "coder_env" "xclaude_small_model" {
  count    = var.xclaude_auth_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "XCLAUDE_SMALL_MODEL"
  value    = var.xclaude_small_model
}

resource "coder_env" "xclaude_effort" {
  count    = var.xclaude_auth_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "XCLAUDE_EFFORT"
  value    = var.xclaude_effort
}

resource "coder_env" "xclaude_permission_mode" {
  count    = var.xclaude_auth_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "XCLAUDE_PERMISSION_MODE"
  value    = var.xclaude_permission_mode
}

resource "coder_env" "xclaude_bypass" {
  count    = var.xclaude_auth_token != "" ? 1 : 0
  agent_id = coder_agent.main.id
  name     = "XCLAUDE_BYPASS"
  value    = var.xclaude_bypass
}

# --- opencode ---


resource "coder_env" "opencode_enable_exa" {
  agent_id = coder_agent.main.id
  name     = "OPENCODE_ENABLE_EXA"
  value    = "1"
}

resource "coder_env" "opencode_experimental" {
  agent_id = coder_agent.main.id
  name     = "OPENCODE_EXPERIMENTAL"
  value    = "true"
}

resource "coder_env" "opencode_experimental_scout" {
  agent_id = coder_agent.main.id
  name     = "OPENCODE_EXPERIMENTAL_SCOUT"
  value    = "true"
}

resource "coder_env" "opencode_experimental_plan_mode" {
  agent_id = coder_agent.main.id
  name     = "OPENCODE_EXPERIMENTAL_PLAN_MODE"
  value    = "true"
}

resource "coder_env" "opencode_experimental_parallel" {
  agent_id = coder_agent.main.id
  name     = "OPENCODE_EXPERIMENTAL_PARALLEL"
  value    = "true"
}

# =============================================================================
# ### 8. Apps
# =============================================================================

module "code-server" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/code-server/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  order    = 1
  port     = 13337
  folder   = "/home/coder"
  share    = "public"
}

resource "coder_app" "opencode" {
  agent_id     = coder_agent.main.id
  slug         = "opencode"
  display_name = "opencode"
  url          = "http://localhost:4096"
  icon         = "/icon/opencode.svg"
  order        = 2
  subdomain    = true
  share        = "public"
}

# =============================================================================
# ### 9. Scripts
# =============================================================================

resource "coder_script" "welcome" {
  agent_id           = coder_agent.main.id
  display_name       = "welcome readme"
  icon               = "/icon/code.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = <<-EOT
    #!/usr/bin/env bash
    set -e

    # Skip if ~/code is a git clone (or about to be) — don't dirty the checkout.
    for i in $(seq 1 60); do
      if [ -d ~/code/.git ]; then exit 0; fi
      sleep 1
    done
    if [ -n "$(ls -A ~/code 2>/dev/null)" ]; then exit 0; fi

    mkdir -p ~/code

    cat > ~/code/README.md <<'MD'
    # Welcome 👋

    Nested Docker plus a background [opencode](https://opencode.ai) server.
    Put your projects under `~/code`.

    ## opencode

    An opencode server runs in the background. Open the **opencode** app from
    the Coder dashboard, or hit <http://localhost:4096>.

    | Command | Action |
    |---|---|
    | `opencode-ctl status`  | is it up? |
    | `opencode-ctl start`   | start it |
    | `opencode-ctl stop`    | stop it |
    | `opencode-ctl restart` | restart it |
    | `opencode-ctl logs`    | follow the server log |

    ## Docker

    Nested Docker is ready — `docker ps` works out of the box.
    See `~/AGENTS.md` for the agent guide.
    MD
  EOT
}

# =============================================================================
# ### 10. Docker
# =============================================================================

resource "docker_network" "private" {
  name = "coder-${local.workspace_id}"
}

resource "docker_volume" "home" {
  name = "coder-${local.workspace_id}-home"
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_volume" "dind" {
  name = "coder-${local.workspace_id}-dind"
  lifecycle {
    ignore_changes = all
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
}

data "docker_registry_image" "workspace" {
  name = local.image
}

# Re-pull on new digest or template_version bump.
resource "docker_image" "workspace" {
  name = data.docker_registry_image.workspace.name
  pull_triggers = [
    data.docker_registry_image.workspace.sha256_digest,
    local.template_version,
  ]
  keep_locally = true
}

resource "docker_image" "dind" {
  name         = "docker:dind"
  keep_locally = true
}

resource "docker_container" "dind" {
  count      = data.coder_workspace.me.start_count
  image      = docker_image.dind.image_id
  name       = local.dind_hostname
  hostname   = local.dind_hostname
  privileged = true
  entrypoint = ["dockerd", "-H", "tcp://0.0.0.0:2375"]

  networks_advanced {
    name = docker_network.private.name
  }

  volumes {
    container_path = "/var/lib/docker"
    volume_name    = docker_volume.dind.name
    read_only      = false
  }
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  image      = docker_image.workspace.image_id
  name       = local.workspace_name
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "DOCKER_HOST=tcp://localhost:2375",
  ]

  # Share DIND's network: localhost ports + DOCKER_HOST work; no hostname/extra_hosts allowed.
  network_mode = "container:${local.dind_hostname}"

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }
  volumes {
    container_path = "/home/coder/.ai"
    host_path      = "/srv/coder/${local.username}/shared/ai"
    read_only      = false
  }

  depends_on = [docker_container.dind]

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
