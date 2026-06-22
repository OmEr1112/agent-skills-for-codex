# Agent Skills for Codex

Production-grade engineering workflows for Codex, covering the development lifecycle from spec to ship.

This Codex plugin provides the core Agent Skills workflows plus slash-command shims for:

| Command | Workflow |
| --- | --- |
| `/spec` | Define what to build before coding |
| `/plan` | Break the work into small verifiable tasks |
| `/build` | Implement one slice at a time |
| `/test` | Prove behavior with tests |
| `/review` | Review correctness, readability, architecture, security, and performance |
| `/code-simplify` | Simplify code without changing behavior |
| `/ship` | Run launch readiness checks with Codex subagents |

## Install in Codex

Clone or copy this repository to Codex's personal plugin directory:

```bash
mkdir -p ~/plugins
git clone <repo-url> ~/plugins/agent-skills
```

If you already have a local copy, make sure the plugin root is:

```text
~/plugins/agent-skills
```

The folder should contain `.codex-plugin/plugin.json`.

### Recommended: one-command install

From the plugin root:

```bash
./install.sh
```

The installer:

- copies the plugin to `~/plugins/agent-skills`
- creates or updates `~/.agents/plugins/marketplace.json`
- runs `codex plugin add agent-skills@personal`
- installs the `/spec`, `/plan`, `/build`, `/test`, `/review`, `/code-simplify`, and `/ship` command shims
- installs and registers the `code-reviewer`, `security-auditor`, and `test-engineer` Codex subagents

Start a new Codex thread after the installer finishes.

## Manual Install

### 1. Add the personal marketplace entry

Codex discovers personal plugins from `~/.agents/plugins/marketplace.json`. Create or update that file so it includes this entry:

```json
{
  "name": "agent-skills",
  "source": {
    "source": "local",
    "path": "./plugins/agent-skills"
  },
  "policy": {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL"
  },
  "category": "Productivity"
}
```

If you do not have a marketplace file yet, this complete file is enough:

```json
{
  "name": "personal",
  "interface": {
    "displayName": "Personal"
  },
  "plugins": [
    {
      "name": "agent-skills",
      "source": {
        "source": "local",
        "path": "./plugins/agent-skills"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity"
    }
  ]
}
```

### 2. Install the plugin

```bash
codex plugin add agent-skills@personal
```

This installs the namespaced plugin skills, such as `agent-skills:spec-driven-development`.

### 3. Install the slash commands

Codex slash-command shims are regular skills with command-style names. Copy them into your global skills directory:

```bash
mkdir -p ~/.agents/skills
cp -R ~/plugins/agent-skills/.agents/skills/{spec,plan,build,test,review,code-simplify,ship} ~/.agents/skills/
```

After this, commands like `/spec`, `/plan`, and `/ship` are available in new Codex threads.

### 4. Install the Codex subagents

The `/ship` command uses Codex multi-agent fan-out with three roles: `code-reviewer`, `security-auditor`, and `test-engineer`.

Copy the role configs:

```bash
mkdir -p ~/.codex/agent-skills-agents
cp -R ~/plugins/agent-skills/.codex/agents/. ~/.codex/agent-skills-agents/
```

Then add these entries to `~/.codex/config.toml`:

```toml
[agents.code-reviewer]
description = "Senior Staff Engineer persona for five-axis review across correctness, readability, architecture, security, and performance."
config_file = "agent-skills-agents/code-reviewer.config.toml"
nickname_candidates = ["Reviewer", "Staff Reviewer", "Code Review"]

[agents.security-auditor]
description = "Security Engineer persona for vulnerability detection, threat modeling, OWASP checks, secrets, auth, and dependency risk."
config_file = "agent-skills-agents/security-auditor.config.toml"
nickname_candidates = ["Security", "Auditor", "Security Review"]

[agents.test-engineer]
description = "QA Engineer persona for test strategy, coverage analysis, Prove-It bug tests, and missing test scenarios."
config_file = "agent-skills-agents/test-engineer.config.toml"
nickname_candidates = ["QA", "Test Engineer", "Coverage"]
```

Codex supports these role entries through `agents.<name>` config blocks. Relative `config_file` paths are resolved from the config file that declares them.

### 5. Start a new Codex thread

Start a new Codex thread after installation. Existing threads may not pick up newly installed skills, slash commands, or subagent roles.

## Updating an Existing Install

When you update the local plugin source:

```bash
codex plugin add agent-skills@personal
cp -R ~/plugins/agent-skills/.agents/skills/{spec,plan,build,test,review,code-simplify,ship} ~/.agents/skills/
cp -R ~/plugins/agent-skills/.codex/agents/. ~/.codex/agent-skills-agents/
```

Then start a new Codex thread.

## More Details

See `docs/codex-setup.md` for implementation notes about command shims, references, and Codex subagent registration.
