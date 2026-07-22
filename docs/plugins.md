# AI Architect plugins (self-hosted)

Plugins add optional capabilities — like answering questions in Slack or
analyzing Jira tickets — on top of your self-hosted AI Architect installation.
Each plugin is a self-contained service you install, configure, and remove with a
single command. Installing, updating, or removing a plugin never affects the base
platform, its databases, or your indexed repositories.

This guide covers installing and managing plugins on an existing self-hosted
deployment. If AI Architect itself is not installed yet, set it up first — see
[Install AI Architect (self-hosted)](https://docs.bito.ai/ai-architect/installation/install-ai-architect-self-hosted).

## Available plugins

| Plugin | What it does | Integrates with |
|---|---|---|
| **Slack AI Assistant** (`ai-assistant`) | Ask AI Architect about your codebase, architecture, and repositories and get grounded answers directly in your Slack channels. | Slack |
| **Bito Task Analyzer** (`task-analyzer`) | Automatically analyzes new and updated Jira tickets and posts its findings back as comments — either on every change or on `@bito` mention. | Jira |

Both plugins run on the same platform your base install already provides. Any
shared infrastructure a plugin needs (such as an event bus or cache) is
provisioned automatically on first use and shared across plugins.

## Prerequisites

Before installing a plugin, make sure you have:

1. **A running self-hosted AI Architect deployment.** Check with `bitoarch status`.
2. **Plugin entitlement on your plan.** Plugins are part of the Bito Enterprise
   plan. If your workspace is not entitled, the installer stops and tells you.
3. **A public URL that Slack or Jira can reach.** Both plugins receive events from
   an external service, so the plugin's endpoint must be reachable from the
   internet over HTTPS with a valid certificate. You provide this during setup.
4. **Access to the integration you're connecting.** Admin rights to create a Slack
   app (for `ai-assistant`), or a Jira account and project (for `task-analyzer`).

## How installing works

Every plugin installs with a single command that runs a short guided setup:

```bash
bitoarch plugin install <name>
```

The installer resolves shared dependencies, provisions the plugin's database,
deploys the service, and then **prompts you for exactly what that plugin needs**.
You don't pass values as flags — you answer the prompts, and each answer applies
immediately. Check health at any time with `bitoarch plugin status <name>`, and
change anything later with `bitoarch plugin config <name>` (it re-runs the same
prompts). If you skip a required value, the plugin is left **pending** and the
output tells you how to finish — nothing is half-installed.

The two plugins and their setup steps follow.

## Set up the Slack AI Assistant

You need admin rights to create a Slack app, and a public HTTPS URL Slack can
reach. Start the install:

```bash
bitoarch plugin install ai-assistant
```

The guided setup then walks you through:

1. **Public URL.** Enter the public HTTPS address where the bot is reachable.
2. **Create the Slack app.** The setup prints a ready-to-paste Slack app
   manifest — your URL and every event/request URL are already filled in — and
   the path to the file to copy it from. Open
   [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From
   an app manifest**, paste it, and create the app.
3. **Credentials.** From the new app's **Basic Information → App Credentials**,
   the setup collects the Client ID, Client Secret, and Signing Secret.
4. **Install to your workspace.** Open the install link the setup prints and click
   **Allow** to authorize the bot in your Slack workspace.

Once it reports healthy, add the bot to a channel with **/invite @Bito**, then
mention **@Bito** with a question or send it a direct message — it reads the full
thread (and supported text attachments) for context. To change any of these
settings later, run `bitoarch plugin config ai-assistant`, which re-runs the same
steps.

## Set up the Bito Task Analyzer

You need a public HTTPS URL Jira can reach, and access to your Jira project. Start
the install:

```bash
bitoarch plugin install task-analyzer
```

The guided setup then walks you through:

1. **Public URL.** Enter the public HTTPS address where the webhook receiver is
   reachable.
2. **Connect Jira.** If you already connected Jira for Insights, the plugin reuses
   that connection. Otherwise it asks for your Jira site URL, account email, and
   an API token (Jira Cloud) or personal access token (Jira Server/Data Center).
3. **Register the webhook.**
   - **Jira Server / Data Center:** registered automatically — nothing to do.
   - **Jira Cloud:** the setup prints a callback URL and the exact steps to add it
     in Jira — **Settings → System → WebHooks → Create a WebHook**, name it
     "Bito AI Architect", paste the URL, tick **Issue** and **Comment: created,
     updated, deleted**, and Save. Jira starts sending events immediately.
4. **Respond mode.** Choose when tickets are analyzed: **on-demand** (the default)
   analyzes a ticket only when a comment mentions **@bito** or **/bito**; **auto**
   analyzes every new or updated ticket.
5. **Projects.** Choose whether the analyzer watches all Jira projects or only
   specific ones.

To change the respond mode, watched projects, or the Jira connection later, run
`bitoarch plugin config task-analyzer`, which re-runs the same steps.

## View or change a plugin's settings

```bash
bitoarch plugin config <name>
```

This shows the plugin's current configuration and walks you through the same setup
prompts, so you can update the public URL, credentials, connection, or any
plugin-specific option. Changes apply immediately.

## Keep plugins up to date

```bash
bitoarch plugin upgrade <name>
```

Upgrades are atomic and preserve your configuration and data. If an upgrade needs
a credential you haven't provided, it holds and tells you what to add rather than
starting a broken version. Installed plugins are also checked for updates daily,
while at least one plugin is installed.

## Manage plugins

```bash
bitoarch plugin list              # installed plugins and versions
bitoarch plugin status            # health of all plugins
bitoarch plugin stop <name>       # pause (keeps config + data)
bitoarch plugin start <name>      # resume
bitoarch plugin uninstall <name>  # remove the service, keep data + config
```

By default, uninstalling **keeps** the plugin's database and configuration, so
reinstalling restores your setup. To also delete them, add `--purge` — on purge,
Bito Task Analyzer additionally removes the webhook it registered in your
self-hosted Jira.

The base lifecycle commands are plugin-aware: `bitoarch stop`, `start`,
`restart`, and `update` include your installed plugins automatically.

## Troubleshooting

| Symptom | What to check |
|---|---|
| Plugin shows **pending** | A required value was not provided. Run `bitoarch plugin config <name>` to add it, then `bitoarch plugin start <name>`. |
| **Not healthy** after install | `bitoarch plugin status <name>` shows the live state. Confirm required credentials are set and the service can start. |
| Slack/Jira events not arriving | Confirm your public URL is reachable from the internet and matches the request/webhook URL configured in Slack or Jira. |
| Need a support bundle | `bitoarch diagnose --bundle` collects a shareable diagnostics archive with per-plugin logs and masked configuration (secrets are redacted). |

## Command reference

| Command | Description |
|---|---|
| `bitoarch plugin install <name>` | Install a plugin and run guided setup. |
| `bitoarch plugin config <name>` | View settings and reconfigure interactively. |
| `bitoarch plugin status [<name>]` | Show plugin health and services. |
| `bitoarch plugin list` | List installed plugins and versions. |
| `bitoarch plugin upgrade <name>` | Upgrade a plugin to the latest version. |
| `bitoarch plugin start <name>` / `stop <name>` | Resume or pause a plugin. |
| `bitoarch plugin uninstall <name>` | Remove a plugin (keeps data; add `--purge` to delete it). |
