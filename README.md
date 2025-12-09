<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->

[![Visit bito.ai][bito-shield]][bito-url]
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://bito.ai/product/ai-architect/">
    <img src="https://github.com/user-attachments/assets/d06b4dcf-9234-4d9a-be65-1e6f1ecfe5fa" alt="Logo" width="150">
  </a>

  <h3 align="center">AI Architect</h3>

  <p align="center">
    System intelligence for your coding agents.
    <br />
    <a href="https://docs.bito.ai/ai-architect/overview"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://www.youtube.com/watch?v=qAMtZ41-xJY">View a demo</a>
    ·
    <a href="https://alpha.bito.ai/home/welcome">Signup for free</a>
    ·
    <a href="https://bito.ai/product/ai-architect/">Learn more</a>
  </p>
</div>

<br />

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of contents</summary>
  <ol>
    <li>
      <a href="#1-overview">Overview</a>
    </li>
    <li>
      <a href="#2-prerequisites">Prerequisites</a>
    </li>
    <li>
      <a href="#3-installation-instructions">Installation instructions</a>
    </li>
    <li>
      <a href="#4-update-repository-list-and-re-index">Update repository list and re-index</a>
    </li>
    <li>
      <a href="#5-setting-up-ai-architect-mcp-in-coding-agents">Setting up AI Architect MCP in coding agents</a>
    </li>
    <li>
      <a href="#6-configuring-ai-architect-for-bito-ai-code-review-agent">Configuring AI Architect for Bito AI Code Review Agent</a>
    </li>
    <li>
      <a href="#7-command-reference">Command reference</a>
    </li>
    <li>
      <a href="#8-troubleshooting-guide">Troubleshooting guide</a>
    </li>
    <li>
      <a href="#9-support--contact">Support & contact</a>
    </li>
  </ol>
</details>

<br />

<!-- Overview -->

## 1. Overview

Bito’s **[AI Architect](https://bito.ai/product/ai-architect/)** builds a knowledge graph of your codebase — from repos to modules to APIs — delivering deep codebase intelligence to the coding agents you already use. This fundamentally changes the game for enterprises with many microservices or large, complex codebases.

Bito provides this in a completely secure fashion, with the AI Architect available on-prem if you desire, and no AI is trained on your code.

> _Click the image below to watch the demo video on YouTube._

[![See Bito's AI Architect demo](https://i.imgur.com/k8vQ31o.png)](https://www.youtube.com/watch?v=qAMtZ41-xJY "See Bito's AI Architect demo")

---

### Key capabilities

| Feature                              | Description |
|--------------------------------------|-------------|
| Grounded 1-shot production-ready code | Learns your services, endpoints, usage examples, and patterns, then feeds them to coding agents to generate production-ready code. |
| Consistent design adherence          | Ensures generated code follows your architecture patterns and coding conventions. |
| Triaging production issues           | Quickly finds root causes from errors, logs, and other signals. |
| Faster onboarding                    | Helps new engineers or AI agents understand system structure faster. |
| Enhanced documentation & diagramming | Improves documentation using internal understanding of module and API connections. |
| Smarter code reviews                 | Performs reviews with full system-wide awareness of dependencies and impacts. |

---

### AI Architect deployment, usage, and pricing 

You can choose to deploy and manage AI Architect in your own infrastructure with your own LLM keys, or let Bito host and manage it in the Bito cloud. An **on-prem deployment with an LLM access key is limited to a maximum of 5 developers**.  AI Architect can be deployed in three different configurations depending on your team size, infrastructure, and management requirements:

- **Personal deployment (Free with your LLM key):** Set up AI Architect on your local machine for individual development work. You'll provide your own LLM API keys for indexing, giving you complete control over the AI models used and associated costs.

- **Team deployment (Free with your LLM key for up to 5 users):** Deploy AI Architect on a shared server within your infrastructure with HTTPS access, allowing multiple team members to connect their AI coding tools to the same MCP server. Each team member can configure AI Architect with their preferred AI coding agent while sharing the same indexed codebase knowledge graph.

- **Enterprise deployment (For teams with more than five developers, requires Bito Enterprise Plan):** Deploy AI Architect in your infrastructure, with the option to use Bito's LLM infrastructure.

> **ℹ️ Usage & Pricing**
>
> Teams of up to five members can use AI Architect for free with their preferred coding agents by using their own LLM API keys. Larger teams require **[Bito Enterprise Plan](https://bito.ai/pricing/)**, which includes bundled LLM tokens. Further, if you want to power Bito Code Review Agent with AI Architect, you will need Bito Enterprise Plan regardless of the size of the team. 
>
> For the best cost and model coverage, we recommend adding both Anthropic and Grok API keys. AI Architect uses Claude Haiku and Grok Code Fast together to index your codebase.
>
> With both keys, indexing costs are typically **$0.20–$0.40 per MB** of indexable code (source files only; binaries, archives, and images are skipped). If only an Anthropic key is provided, indexing costs rise to **$1.00–$1.50 per MB**.

Please feel free to contact us at support@bito.ai to subscribe to the Bito Enterprise Plan for your on-prem deployment or have Bito manage the AI Architect.  

---

<br />

<!-- Prerequisites -->

## 2. Prerequisites

Before you start the AI Architect setup in your environment, make sure you have the following ready:

### **LLM API Keys**
Required for personal use of AI Architect. Supports **Anthropic (Claude)** and **Grok** models. Add both keys for the best cost and coverage.

### **Bito Access Key**
You’ll need a **Bito account** and a **Bito Access Key** to authenticate AI Architect. You can sign up for a Bito account at https://alpha.bito.ai, and create an access key from Settings -> Advanced Settings **[Link](https://alpha.bito.ai/home/advanced)**. 

### **Git Access Token**
Used by AI Architect to read and index your repositories. Bito supports **GitHub**, **GitLab**, and **Bitbucket**.
- **GitHub classic Token with `repo` access**  Fine-grained tokens are not supported. [Learn more](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic)  
- **GitLab token with `api` scope)** [Learn more](https://docs.gitlab.com/user/profile/personal_access_tokens/#create-a-personal-access-token)
- **Bitbucket API Token**  [Learn more](https://support.atlassian.com/bitbucket-cloud/docs/create-an-api-token/)

---

### System requirements

The AI Architect supports the following operating systems:

- macOS
- Unix-based systems
- Windows (via WSL2)

---

<br />

<!-- Installation instructions -->

## 3. Installation instructions

Setting up AI Architect has three main steps:
1. Setting up AI Architect
2. Configuring repositories to index
3. Start the indexing process

Once the indexing is complete, you can configure MCP in any coding or chat agent that supports MCP. This guide will walk you through installing and setting up AI Architect in a self-hosted environment.  

**Step 1- Download AI Architect**

Download the latest version of AI Architect package from **[GitHub repository](https://github.com/gitbito/ai-architect)**.

---

**Step 2- Extract package**

Run the following command to extract the downloaded package:

```bash
tar -xzf bito-cis-*.tar.gz
```

Move inside the folder:

```bash
cd bito-cis-*
```
---

**Step 3- Run setup**

```bash
./setup.sh
```

**You'll need to provide the following details when prompted:**
- **Bito API Key** (required) - Your Bito authentication key
- **Git Access Token** (required) - Personal access token for your Git provider (GitHub, GitLab or BitBucket)
- **LLM Keys** (required unless you have a Bito Enterprise Plan)
- 
> Refer to the [Prerequisites section](#2-prerequisites) for details on how to obtain these. Once the setup is complete, your **Bito MCP URL** and **Bito MCP Access Token** will be displayed.
> Make sure to store them in a safe place, you'll need them later when configuring MCP server in your AI coding agent (e.g., Claude Code, Cursor, Windsurf, GitHub Copilot (VS Code), etc.).

---

**Step 4- Add repositories**

Edit `config.yaml` file to add your repositories for indexing:

```yaml
repository:
  configured_repos:
    - namespace: your-org/repo-name-1
    - namespace: your-org/repo-name-2
    - namespace: your-org/repo-name-3
```

Then apply the configuration:

```bash
bitoarch config repo add config.yaml
```
---

**Step 5- Start indexing**

Trigger workspace synchronization to index your repositories:

```bash
bitoarch manager sync
```
The indexing process will take approximately 3-10 minutes per repository. Smaller repos take less time.

---

**Step 6- Check indexing status**

Run this command to check the status of your indexing:

```bash
bitoarch manager status
```

**Status indicators:**

- `in_progress` - Indexing is running
- `completed` - All repositories indexed
- `failed` - Check logs for errors

> Once the indexing is complete, you can configure AI Architect in the coding or chat agent of your choice that supports MCP.
> You will need the Bito MCP URL and the access token generated during setup.
> You will need to ensure the AI Architect server is accessible over HTTPS if it is set up for team use.

---

<br />

<!-- Update repository list and re-index -->

## 4. Update repository list and re-index

You can update the repository list and re-index anytime after the initial setup through config.yaml file. 

Edit `config.yaml` file to add/remove repositories:

```bash
vim config.yaml
```

To apply the changes, run this command:

```bash
bitoarch config repo update config.yaml
```

Start the re-indexing process using this command:

```bash
bitoarch manager sync
```

---

<br />

<!-- Setting up AI Architect MCP in coding agents -->

## 5. Setting up AI Architect MCP in coding agents

Configure the MCP server in supported AI coding tools such as Claude Code, Cursor, Windsurf, and GitHub Copilot (VS Code).

Select your AI coding tool from the options below and follow the step-by-step installation guide to set up AI Architect seamlessly:

- [Guide for Claude Code](https://docs.bito.ai/ai-architect/guide-for-claude-code)
- [Guide for Cursor](https://docs.bito.ai/ai-architect/guide-for-cursor)
- [Guide for Windsurf](https://docs.bito.ai/ai-architect/guide-for-windsurf)
- [Guide for GitHub Copilot (VS Code)](https://docs.bito.ai/ai-architect/guide-for-github-copilot-vs-code)

---

<br />

<!-- Configuring AI Architect for Bito AI Code Review Agent -->

## 6. Configuring AI Architect for Bito AI Code Review Agent

---

<br />

<!-- Command reference -->

## 7. Command reference

Quick reference to CLI commands for managing your AI Architect.

### 7.1 Platform status commands

| Command                                  | Description              | Example                             |
| ---------------------------------------- | ------------------------ | ----------------------------------- |
| `bitoarch platform status`               | View all services status | Shows running/stopped state         |
| `bitoarch platform info`                 | Get platform details     | Version, ports, resource usage      |
| `bitoarch platform rotate-token <token>` | Rotate MCP access token  | Updates token and restarts provider |

### 7.2 Configuration management

| Command                                   | Description                 | Example                                   |
| ----------------------------------------- | --------------------------- | ----------------------------------------- |
| `bitoarch config repo add <yaml-file>`    | Add configuration from YAML | `bitoarch config repo add config.yaml`    |
| `bitoarch config repo get`                | Get current configuration   | `bitoarch config repo get`                |
| `bitoarch config repo update <yaml-file>` | Update configuration        | `bitoarch config repo update config.yaml` |

### 7.3 Workspace synchronization

| Command                   | Description                | Example                                |
| ------------------------- | -------------------------- | -------------------------------------- |
| `bitoarch manager status` | Check indexing/sync status | Get current sync status                |
| `bitoarch manager sync`   | Simple workspace sync      | Triggers sync for configured workspace |

### 7.4 MCP operations

| Command                              | Description              | Example                            |
| ------------------------------------ | ------------------------ | ---------------------------------- |
| `bitoarch provider mcp tools`        | List available MCP tools | View repository intelligence tools |
| `bitoarch provider mcp resources`    | List MCP resources       | View available data sources        |
| `bitoarch provider mcp capabilities` | Get server capabilities  | Check available features           |
| `bitoarch provider mcp test`         | Test MCP connection      | Verify server connectivity         |

**MCP tools:** The MCP server provides tools for repository intelligence and analysis. Use `bitoarch provider mcp tools` to see the current list of available tools dynamically fetched from the server. Common tools include:

- Repository browsing and search
- Dependency analysis
- Cluster identification
- Technology stack discovery

**MCP resources:** Resources represent data sources for repository information. Use `bitoarch provider mcp resources` to see available resource URIs dynamically fetched from the server.

### 7.5 Output options

Add these flags to any command:

| Flag            | Purpose           | Example                |
| --------------- | ----------------- | ---------------------- |
| `--format json` | JSON output       | For automation/scripts |
| `--help`        | Show command help | Get usage information  |

---

<br />

<!-- Troubleshooting guide -->

## 8. Troubleshooting guide

### 8.1 Services not starting

```bash
# Check setup log
tail -f setup.log

# View service logs
bitoarch platform logs
```

### 8.2 Port conflicts

Before running setup, edit `.env.default`:

```bash
vim .env.default
# Change: CIS_PROVIDER_EXTERNAL_PORT, CIS_MANAGER_EXTERNAL_PORT, etc.
```

### 8.3 Indexing issues

```bash
# Check manager status
bitoarch manager status --raw

# View manager logs
bitoarch platform logs cis-manager
```

### 8.4 Reset installation

```bash
# Complete clean (removes all data and configuration)
./setup.sh --clean

# Then run setup again
./setup.sh
```

---

<br />

<!-- Support & contact -->

## 9. Support & contact

For comprehensive information and guidance on the AI Architect, including installation and configuration instructions, please refer to our detailed **[documentation available here](https://docs.bito.ai/ai-architect/overview)**. Should you require further assistance or have any inquiries, our support team is readily available to assist you.

Feel free to reach out to us via email at: **[support@bito.ai](mailto:support@bito.ai)**

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[bito-shield]: https://img.shields.io/badge/Visit%20bito.ai-black.svg?style=for-the-badge&colorB=%232baaff
[bito-url]: https://bito.ai/
[contributors-shield]: https://img.shields.io/github/contributors/gitbito/ai-architect.svg?style=for-the-badge
[contributors-url]: https://github.com/gitbito/ai-architect/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/gitbito/ai-architect.svg?style=for-the-badge
[forks-url]: https://github.com/gitbito/ai-architect/network/members
[stars-shield]: https://img.shields.io/github/stars/gitbito/ai-architect.svg?style=for-the-badge
[stars-url]: https://github.com/gitbito/ai-architect/stargazers
[issues-shield]: https://img.shields.io/github/issues/gitbito/ai-architect.svg?style=for-the-badge
[issues-url]: https://github.com/gitbito/ai-architect/issues
[license-shield]: https://img.shields.io/github/license/gitbito/ai-architect.svg?style=for-the-badge
[license-url]: https://github.com/gitbito/ai-architect?tab=MIT-1-ov-file#readme
