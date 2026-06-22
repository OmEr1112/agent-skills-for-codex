#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="agent-skills"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/plugins/${PLUGIN_NAME}"
MARKETPLACE_PATH="${HOME}/.agents/plugins/marketplace.json"
GLOBAL_SKILLS_DIR="${HOME}/.agents/skills"
GLOBAL_AGENTS_DIR="${HOME}/.codex/agent-skills-agents"
CODEX_CONFIG="${HOME}/.codex/config.toml"

if [[ ! -f "${SOURCE_DIR}/.codex-plugin/plugin.json" ]]; then
  echo "Error: run this from the ${PLUGIN_NAME} plugin root." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required to update Codex config files." >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "Error: codex CLI was not found in PATH." >&2
  exit 1
fi

mkdir -p "${HOME}/plugins" "${GLOBAL_SKILLS_DIR}" "${GLOBAL_AGENTS_DIR}" "$(dirname "${MARKETPLACE_PATH}")" "$(dirname "${CODEX_CONFIG}")"

if [[ "${SOURCE_DIR}" != "${TARGET_DIR}" ]]; then
  if [[ -e "${TARGET_DIR}" ]]; then
    BACKUP_DIR="${TARGET_DIR}.backup.$(date +%Y%m%d%H%M%S)"
    mv "${TARGET_DIR}" "${BACKUP_DIR}"
    echo "Existing ${TARGET_DIR} moved to ${BACKUP_DIR}."
  fi
  mkdir -p "${TARGET_DIR}"
  cp -R "${SOURCE_DIR}/." "${TARGET_DIR}/"
  find "${TARGET_DIR}" -name ".DS_Store" -delete
fi

python3 - "${MARKETPLACE_PATH}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]).expanduser()
if path.exists():
    data = json.loads(path.read_text())
else:
    data = {
        "name": "personal",
        "interface": {"displayName": "Personal"},
        "plugins": [],
    }

data.setdefault("name", "personal")
data.setdefault("interface", {}).setdefault("displayName", "Personal")
plugins = [p for p in data.get("plugins", []) if p.get("name") != "agent-skills"]
plugins.append({
    "name": "agent-skills",
    "source": {
        "source": "local",
        "path": "./plugins/agent-skills",
    },
    "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL",
    },
    "category": "Productivity",
})
data["plugins"] = plugins
path.write_text(json.dumps(data, indent=2) + "\n")
PY

codex plugin add "${PLUGIN_NAME}@personal"

for command in spec plan build test review code-simplify ship; do
  rm -rf "${GLOBAL_SKILLS_DIR}/${command}"
  cp -R "${TARGET_DIR}/.agents/skills/${command}" "${GLOBAL_SKILLS_DIR}/"
done

cp -R "${TARGET_DIR}/.codex/agents/." "${GLOBAL_AGENTS_DIR}/"

python3 - "${CODEX_CONFIG}" "${GLOBAL_AGENTS_DIR}" <<'PY'
import re
import sys
from pathlib import Path

config_path = Path(sys.argv[1]).expanduser()
agents_dir = Path(sys.argv[2]).expanduser()
text = config_path.read_text() if config_path.exists() else ""

blocks = {
    "code-reviewer": {
        "description": "Senior Staff Engineer persona for five-axis review across correctness, readability, architecture, security, and performance.",
        "file": agents_dir / "code-reviewer.config.toml",
        "nicknames": '["Reviewer", "Staff Reviewer", "Code Review"]',
    },
    "security-auditor": {
        "description": "Security Engineer persona for vulnerability detection, threat modeling, OWASP checks, secrets, auth, and dependency risk.",
        "file": agents_dir / "security-auditor.config.toml",
        "nicknames": '["Security", "Auditor", "Security Review"]',
    },
    "test-engineer": {
        "description": "QA Engineer persona for test strategy, coverage analysis, Prove-It bug tests, and missing test scenarios.",
        "file": agents_dir / "test-engineer.config.toml",
        "nicknames": '["QA", "Test Engineer", "Coverage"]',
    },
}

for name in blocks:
    pattern = rf"\n?\[agents\.{re.escape(name)}\]\n(?:[^\n]*\n)*?(?=\n\[|\Z)"
    text = re.sub(pattern, "\n", text).rstrip() + "\n"

for name, block in blocks.items():
    text += f"""
[agents.{name}]
description = "{block['description']}"
config_file = "{block['file']}"
nickname_candidates = {block['nicknames']}
"""

config_path.write_text(text.lstrip())
PY

echo "Agent Skills for Codex installed."
echo "Start a new Codex thread before using /spec, /plan, /build, /test, /review, /code-simplify, or /ship."
