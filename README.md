# Agent Skills for Codex — inspired by Addy Osmani's Agent Skills

Codex port by OmEr1112. Inspired by and adapted from [Addy Osmani's Agent Skills](https://github.com/addyosmani/agent-skills).

Original concept and workflows by [Addy Osmani](https://github.com/addyosmani). This repository packages those software-development lifecycle skills for OpenAI Codex with Codex-native plugin metadata, slash-command shims, and subagent role configuration.

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

## What This Gives You

- 23 reusable Agent Skills for software engineering workflows.
- 7 Codex slash commands that mirror the original lifecycle commands.
- 3 Codex subagent roles for launch review: `code-reviewer`, `security-auditor`, and `test-engineer`.
- Codex plugin packaging through `.codex-plugin/plugin.json`.
- A one-command installer for local Codex setup.

Codex plugin structure follows OpenAI's plugin documentation: plugins use `.codex-plugin/plugin.json`, bundled skills live under `skills/<name>/SKILL.md`, and marketplace entries tell Codex where to load the plugin from. See [OpenAI's Codex plugin docs](https://developers.openai.com/codex/plugins/build).

## Install in Codex

Clone this repository:

```bash
git clone https://github.com/OmEr1112/agent-skills-for-codex.git
cd agent-skills-for-codex
```

Then run the installer:

```bash
./install.sh
```

The installer copies the plugin into Codex's personal plugin location:

```text
~/plugins/agent-skills
```

Then it:

- creates or updates `~/.agents/plugins/marketplace.json`
- runs `codex plugin add agent-skills@personal`
- installs the `/spec`, `/plan`, `/build`, `/test`, `/review`, `/code-simplify`, and `/ship` command shims
- installs and registers the `code-reviewer`, `security-auditor`, and `test-engineer` Codex subagents

Start a new Codex thread after the installer finishes.

## How To Use It

After installing, start a new Codex thread in the project you want to work on. Then use the commands naturally:

```text
/spec Build a dashboard for tracking customer follow-ups.
/plan
/build
/test
/review
/code-simplify
/ship
```

Typical workflow:

1. Use `/spec` to define the feature before writing code.
2. Use `/plan` to break the spec into small, verifiable tasks.
3. Use `/build` to implement the next task with tests.
4. Use `/test` when you want a TDD or bug reproduction pass.
5. Use `/review` before merging.
6. Use `/code-simplify` to reduce complexity while preserving behavior.
7. Use `/ship` before production release; it fans out to Codex subagents for code review, security review, and test coverage analysis.

You can also invoke the namespaced skills directly in normal language:

```text
Use Agent Skills to write a spec for this feature.
Use Agent Skills to review the current diff.
Use Agent Skills to prepare this change for shipping.
```

## Manual Install

The installer is recommended. Use this manual path only if you want to wire the plugin into Codex yourself.

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

Pull the latest version and rerun the installer:

```bash
git pull
./install.sh
```

Then start a new Codex thread.

## Credit

This project is inspired by [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills), created by [Addy Osmani](https://github.com/addyosmani). The workflows, lifecycle command model, and specialist review personas come from that original project. This repository adapts them for Codex with Codex plugin packaging, command shims, and Codex subagent configuration.

## More Details

See `docs/codex-setup.md` for implementation notes about command shims, references, and Codex subagent registration.
