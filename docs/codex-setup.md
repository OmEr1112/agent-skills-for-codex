# Using agent-skills with Codex

Codex discovers command-like workflows through agent skills. This repo includes `.codex-plugin/plugin.json` for the core plugin skills, plus Spec Kit-style command shims under `.agents/skills/` for exact slash command names such as `/spec` and `/build`.

There are two install steps because Codex loads them through different roots:

1. `codex plugin add agent-skills@personal` installs the namespaced core skills, such as `agent-skills:spec-driven-development`.
2. Copying `.agents/skills/*` into `~/.agents/skills/` installs the unprefixed command skills, such as `/spec`.

## Install locally

For a local development install, put this repository at the personal plugin path Codex expects. If `~/plugins/agent-skills` already exists, update that copy instead of nesting another copy inside it.

```bash
mkdir -p ~/plugins
cp -R /path/to/agent-skills ~/plugins/
codex plugin add agent-skills@personal
mkdir -p ~/.agents/skills
cp -R ~/plugins/agent-skills/.agents/skills/{spec,plan,build,test,review,code-simplify,ship} ~/.agents/skills/
mkdir -p ~/.codex/agent-skills-agents
cp -R ~/plugins/agent-skills/.codex/agents/. ~/.codex/agent-skills-agents/
```

Then add role entries like these to `~/.codex/config.toml` if you want the personas available outside this repo. Use real absolute paths for `config_file` (for this machine, that path is `/Users/rooted/.codex/agent-skills-agents/...`).

```toml
[agents.code-reviewer]
description = "Senior Staff Engineer persona for five-axis review across correctness, readability, architecture, security, and performance."
config_file = "/Users/rooted/.codex/agent-skills-agents/code-reviewer.config.toml"
nickname_candidates = ["Reviewer", "Staff Reviewer", "Code Review"]

[agents.security-auditor]
description = "Security Engineer persona for vulnerability detection, threat modeling, OWASP checks, secrets, auth, and dependency risk."
config_file = "/Users/rooted/.codex/agent-skills-agents/security-auditor.config.toml"
nickname_candidates = ["Security", "Auditor", "Security Review"]

[agents.test-engineer]
description = "QA Engineer persona for test strategy, coverage analysis, Prove-It bug tests, and missing test scenarios."
config_file = "/Users/rooted/.codex/agent-skills-agents/test-engineer.config.toml"
nickname_candidates = ["QA", "Test Engineer", "Coverage"]
```

The default personal marketplace lives at `~/.agents/plugins/marketplace.json`. It should include an entry like this:

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

After installing or updating the plugin, start a new Codex thread so the new command and skill metadata is loaded.

## Commands

The Codex command shims live in `.agents/skills/`. Their skill names become the command names, matching Spec Kit's Codex integration model. Each shim is written as a Codex skill and routes to the same lifecycle workflow as the original command.

| Command | Skills used |
| --- | --- |
| `/spec` | `spec-driven-development` |
| `/plan` | `planning-and-task-breakdown` |
| `/build` | `incremental-implementation`, `test-driven-development` |
| `/test` | `test-driven-development`, plus browser testing when relevant |
| `/review` | `code-review-and-quality` |
| `/code-simplify` | `code-simplification` |
| `/ship` | `shipping-and-launch`, plus review/security/test passes |

## References and agents

The `references/` directory is part of the original repo. It contains supplementary checklists used by the skills, such as testing, security, performance, and accessibility references.

Codex supports subagents through the multi-agent tools and `agents.<name>` entries in `config.toml`; this plugin provides Codex role config in `.codex/config.toml` and `.codex/agents/*.config.toml`.

Codex plugin manifests currently validate `skills`, `apps`, and `mcpServers`; they do not have an `agents` manifest field. That means installing the plugin loads the skills, while registering persona-style subagents requires config entries.

## Development update loop

If you are iterating on a local installed copy, update the plugin source under `~/plugins/agent-skills`, reinstall, then copy the command shims into your Codex skill directory:

```bash
cp -R ~/plugins/agent-skills/.agents/skills/{spec,plan,build,test,review,code-simplify,ship} ~/.agents/skills/
cp -R ~/plugins/agent-skills/.codex/agents/. ~/.codex/agent-skills-agents/
codex plugin add agent-skills@personal
```

Start a new Codex thread after reinstalling. Existing threads may not pick up newly added commands.
