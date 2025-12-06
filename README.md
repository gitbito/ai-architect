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
    AI that understands your codebase inside out — and codes like your team.
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
      <a href="#overview">Overview</a>
    </li>
    <li>
      <a href="#Prerequisites">Prerequisites</a>
    </li>
    <li>
      <a href="#installation-options">Installation options</a>
    </li>
    <li>
      <a href="#installation-instructions">Installation instructions</a>
    </li>
    <li>
      <a href="#configuration-management">Configuration management</a>
    </li>
    <li>
      <a href="#indexing-repositories">Indexing repositories</a>
    </li>
    <li>
      <a href="#mcp-configuration">MCP configuration</a>
    </li>
    <li>
      <a href="#command-reference">Command reference</a>
    </li>
    <li>
      <a href="#troubleshooting-guide">Troubleshooting guide</a>
    </li>
    <li>
      <a href="#support-contact">Support & contact</a>
    </li>
  </ol>
</details>

<br />

<!-- Overview -->

## 1. Overview

> _Click the image below to watch the demo video on YouTube._

[![See Bito's AI Architect demo](https://i3.ytimg.com/vi/qAMtZ41-xJY/maxresdefault.jpg)](https://www.youtube.com/watch?v=qAMtZ41-xJY "See Bito's AI Architect demo")

Bito’s **[AI Architect](https://bito.ai/product/ai-architect/)** builds a knowledge graph of your codebase — from repos to modules to APIs — delivering deep codebase intelligence to the coding agents you already use. This fundamentally changes the game for enterprises with many microservices or large, complex codebases.

Bito provides this in a completely secure fashion, with the AI Architect available on-prem if you desire, and no AI is trained on your code.

We suggest you use Anthropic AND Grok as your LLMs as that provides the best coverage and the best cost of indexing. It will cost you approximately USD$0.20 - 0.40 per MB of indexable code (we do not index binaries, TARs, zips, images, etc). If you do not provide a Grok key, your indexing costs will be significantly higher, approximately USD$1.00 - $1.50 per MB of indexable code.

### 1.1 Key capabilities of the AI Architect include:

- **Grounded 1-shot production-ready code** — The AI Architect learns all your services, endpoints, code usage examples, and architectural patterns. The agent automatically feeds those to your coding agent (Claude Code, Cursor, Codex, any MCP client) to provide it the necessary information to quickly and efficiently create production ready code.

- **Consistent design adherence** — Code generated aligns with your architecture patterns and coding conventions.

- **Triaging production issues** — easily and quickly find root causes to production issues based on errors/logs/etc.

- **Faster onboarding** — new engineers or AI agents can quickly understand how a system or component system structure.

- **Enhanced documentation and diagramming** — through its internal understanding of interconnections between modules and APIs.

- **Smarter code reviews** — reviews with system-wide awareness of dependencies and impacts.

### 1.2 How you can use AI Architect

AI Architect is designed to be flexible and can power multiple use cases across different AI coding tools and workflows.

You can integrate AI Architect via MCP server (Model Context Protocol) to connect with tools like Claude Code, Cursor, Windsurf, GitHub Copilot (VS Code), and more. It helps these tools understand your codebase and workflows better, resulting in more accurate and reliable suggestions.

**AI Architect can be deployed in two ways:**

1. **On-premises deployment** – Install and run AI Architect on your own infrastructure.

   - See the installation instructions given below.

2. **Bito-hosted version** – Use the hosted version managed by Bito.
   - Contact [support@bito.ai](mailto:support@bito.ai) for a trial

<br />

<!-- Prerequisites -->

## 2. Prerequisites

### 2.1 Required accounts and tokens

1. **Bito API Key:** This is your **Bito Access Key**, which you can obtain from the **[Bito Cloud settings](https://alpha.bito.ai/home/advanced)**.

   - **[View Guide](https://docs.bito.ai/help/account-and-settings/access-key)**

2. **Git provider:** We support GitHub, GitLab, and Bitbucket. So, you'll need an account on one of these Git providers to index your repositories with AI Architect.

3. **Git Access Token:** A personal access token from your chosen Git provider is required. You'll use this token to allow AI Architect to read and index your repositories.

   - **GitHub Personal Access Token (Classic):** To use GitHub repositories with AI Architect, ensure you have a CLASSIC personal access token with repo access. We do not support fine-grained tokens currently.

     - **[View Guide](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic)**

   - **GitLab Personal Access Token:** To use GitLab repositories with AI Architect, a token with API access is required.
     - **[View Guide](https://docs.gitlab.com/user/profile/personal_access_tokens/#create-a-personal-access-token)**
   - **Bitbucket API Token:** To use Bitbucket repositories with AI Architect, an API token is required.
     - **[View Guide](https://support.atlassian.com/bitbucket-cloud/docs/create-an-api-token/)**

<br />

### 2.2 System requirements

The AI Architect supports the following operating systems:

- macOS
- Unix-based systems
- Windows (via WSL2)

<br />

<!-- Installation options -->

## 3. Installation options

AI Architect can be deployed in three different configurations depending on your team size, infrastructure, and security requirements:

### 3.1 Personal use (with your LLM key)

Set up AI Architect on your local machine for individual development work. You'll provide your own LLM API keys for indexing, giving you complete control over the AI models used and associated costs.

**Best for:** Individual developers who want codebase understanding on their personal machine.

### 3.2 Team / shared access (with your LLM key)

Deploy AI Architect on a shared server within your infrastructure, allowing multiple team members to connect their AI coding tools to the same MCP server. Each team member can configure AI Architect with their preferred AI coding agent while sharing the same indexed codebase knowledge graph.

**Best for:** Development teams that want to share codebase intelligence across the team while managing their own LLM costs.

### 3.3 Enterprise deployment (requires Bito Enterprise Plan)

Deploy AI Architect on your infrastructure (local machine or shared server) with indexing managed by Bito. Instead of providing your own LLM keys, Bito handles the repository indexing process, simplifying setup and cost management.

**Best for:** Organizations that prefer managed indexing without handling individual LLM API keys and costs.

<br />

<!-- Installation instructions -->

## 4. Installation instructions

This guide will walk you through the installation and setup of AI Architect in a self-hosted environment.

### 4.1 Download AI Architect

Download the latest version of AI Architect package from our **[GitHub repository](https://github.com/gitbito/ai-architect)**.

### 4.2 Extract package

Run the following command to extract the downloaded package:

```bash
tar -xzf bito-cis-*.tar.gz
```

Move inside the folder:

```bash
cd bito-cis-*
```

### 4.3 Run setup

```bash
./setup.sh
```

**You'll need to provide the following details when prompted:**

- **Bito API Key** (required) - Your Bito authentication key
- **Select your Git provider from available options:**
  - GitLab
  - GitHub
  - Bitbucket
- **Git Access Token** (required) - Personal access token for your Git provider

**Note:** Refer to the [Prerequisites section](#prerequisites) for details on how to obtain these.

**Note:** Once the setup is complete, your **Bito MCP URL** and **Bito MCP Access Token** will be displayed. Make sure to store them in a safe place, you'll need them later when configuring MCP server in your AI coding agent (e.g., Claude Code, Cursor, Windsurf, GitHub Copilot (VS Code), etc.).

### 4.4 Add repositories

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

### 4.5 Start indexing

Trigger workspace synchronization to index your repositories:

```bash
bitoarch manager sync
```

Indexing process will take approximately 3-10 minutes per repository. Smaller repos take less time.

### 4.6 Check indexing status

Run this command to check the status of your indexing:

```bash
bitoarch manager status
```

**Status indicators:**

- `in_progress` - Indexing is running
- `completed` - All repositories indexed
- `failed` - Check logs for errors

## 4.7 Use AI Architect in your coding agents

Configure MCP server in supported AI coding tools such as Claude Code, Cursor, Windsurf, and GitHub Copilot (VS Code).

Select your AI coding tool from the options below and follow the step-by-step installation guide to seamlessly set up AI Architect:

- [Guide for Claude Code](https://docs.bito.ai/ai-architect/guide-for-claude-code)
- [Guide for Cursor](https://docs.bito.ai/ai-architect/guide-for-cursor)
- [Guide for Windsurf](https://docs.bito.ai/ai-architect/guide-for-windsurf)
- [Guide for GitHub Copilot (VS Code)](https://docs.bito.ai/ai-architect/guide-for-github-copilot-vs-code)

## 4.8 Update repository list and re-index

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

<br />

<!-- Configuration management -->

## 5. Configuration management

<br />

<!-- Indexing repositories -->

## 6. Indexing repositories

<br />

<!-- MCP configuration -->

## 7. MCP configuration

### 7.1 MCP server overview

### 7.2 Setting up Architect MCP in coding agents

### 7.3 Configuring Architect for Bito Code Review Agent

<br />

<!-- Command reference -->

## 8. Command reference

Quick reference to CLI commands for managing your AI Architect.

## 8.1 Platform status commands

| Command                                  | Description              | Example                             |
| ---------------------------------------- | ------------------------ | ----------------------------------- |
| `bitoarch platform status`               | View all services status | Shows running/stopped state         |
| `bitoarch platform info`                 | Get platform details     | Version, ports, resource usage      |
| `bitoarch platform rotate-token <token>` | Rotate MCP access token  | Updates token and restarts provider |

## 8.2 Configuration management

| Command                                   | Description                 | Example                                   |
| ----------------------------------------- | --------------------------- | ----------------------------------------- |
| `bitoarch config repo add <yaml-file>`    | Add configuration from YAML | `bitoarch config repo add config.yaml`    |
| `bitoarch config repo get`                | Get current configuration   | `bitoarch config repo get`                |
| `bitoarch config repo update <yaml-file>` | Update configuration        | `bitoarch config repo update config.yaml` |

## 8.3 Workspace synchronization

| Command                   | Description                | Example                                |
| ------------------------- | -------------------------- | -------------------------------------- |
| `bitoarch manager status` | Check indexing/sync status | Get current sync status                |
| `bitoarch manager sync`   | Simple workspace sync      | Triggers sync for configured workspace |

## 8.4 MCP operations

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

## 8.5 Output options

Add these flags to any command:

| Flag            | Purpose           | Example                |
| --------------- | ----------------- | ---------------------- |
| `--format json` | JSON output       | For automation/scripts |
| `--help`        | Show command help | Get usage information  |

<br />

<!-- Troubleshooting guide -->

## 9. Troubleshooting guide

### 9.1 Services not starting

```bash
# Check setup log
tail -f setup.log

# View service logs
bitoarch platform logs
```

### 9.2 Port conflicts

Before running setup, edit `.env.default`:

```bash
vim .env.default
# Change: CIS_PROVIDER_EXTERNAL_PORT, CIS_MANAGER_EXTERNAL_PORT, etc.
```

### 9.3 Indexing issues

```bash
# Check manager status
bitoarch manager status --raw

# View manager logs
bitoarch platform logs cis-manager
```

### 9.4 Reset installation

```bash
# Complete clean (removes all data and configuration)
./setup.sh --clean

# Then run setup again
./setup.sh
```

<br />

<!-- Support & contact -->

## 10. Support & contact

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
