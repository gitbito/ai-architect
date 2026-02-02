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
      <a href="#9-upgrading-ai-architect">Upgrading AI Architect</a>
    </li>
    <li>
      <a href="#10-support--contact">Support & contact</a>
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

- **Enterprise deployment (For teams with more than five developers, requires Bito Enterprise Plan):** Deploy AI Architect in your infrastructure, with the option to use Bito's LLM infrastructure. Please contact [support@bito.ai](mailto:support@bito.ai) to discuss a free Enterprise trial or to subscribe.

> **ℹ️ Usage & Pricing**
>
> Teams of up to five members can use AI Architect for free with their preferred coding agents by using their own LLM API keys. Larger teams require **[Bito Enterprise Plan](https://bito.ai/pricing/)**, which includes bundled LLM tokens. Further, if you want to power Bito Code Review Agent with AI Architect, you will need Bito Enterprise Plan regardless of the size of the team. 
>
> For the best cost and model coverage, we recommend adding both Anthropic and Grok API keys. AI Architect uses Claude Haiku and Grok Code Fast together to index your codebase.
>
> With both keys, indexing costs are typically **$0.20–$0.40 per MB** of indexable code (source files only; binaries, archives, and images are skipped). If only an Anthropic key is provided, indexing costs rise to **$1.00–$1.50 per MB**.

Please contact us at [support@bito.ai](mailto:support@bito.ai) for a **free Enterprise trial** for your on-prem deployment, to subscribe to a paid plan, or to have Bito manage the AI Architect.

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
- **Bitbucket Access Token:** Depending on your Bitbucket setup, you may need one of the following:
  - For **Bitbucket Cloud** use **API Token**. [Learn more](https://support.atlassian.com/bitbucket-cloud/docs/create-an-api-token/)
  - For **Bitbucket Enterprise (Self-Hosted)** use **HTTP Access Token**. [Learn more](https://confluence.atlassian.com/bitbucketserver/personal-access-tokens-939515499.html)

---

### System requirements

The AI Architect supports the following operating systems:

- macOS
- Unix-based systems
- Windows (via WSL2)

---

### WSL2 is required for Windows users

If you're running Windows, Windows Subsystem for Linux 2 (WSL2) must be installed before proceeding.

**To install WSL2:**

1. Open PowerShell or Command Prompt as Administrator
2. Run the following command:
```bash
   wsl --install
```
3. Set up your Ubuntu username and password when prompted

### Docker Desktop / Docker Service (required)

**Docker Compose** is required to run AI Architect. The easiest and recommended way to get Docker Compose is to install **Docker Desktop**.

Docker Desktop includes Docker Compose along with Docker Engine and Docker CLI which are Compose prerequisites.

[Install Docker Desktop](https://docs.docker.com/compose/install)

**Configuration for Windows (WSL2):**

If you're using Windows with WSL2, you need to enable Docker integration with your WSL distribution:

1. Open **Docker Desktop**
2. Go to **Settings > Resources > WSL Integration**
3. Enable integration for your WSL distribution (e.g., Ubuntu)
4. Click **Apply**

---

### Kubernetes cluster (optional)

AI Architect supports Kubernetes as an alternative deployment option. For production deployments, a Kubernetes cluster must be pre-configured on your infrastructure.

For testing and development purposes, you can create a local cluster using KIND (Kubernetes in Docker). Refer to the [Kubernetes Deployment Guide](https://github.com/gitbito/ai-architect/blob/main/docs/KUBERNETES_DEPLOYMENT.md) for detailed instructions.

> **Note:** Kubernetes deployment support is available from version 1.3.0 onwards.

---

<br />

<!-- Installation instructions -->

## 3. Installation instructions

Setting up AI Architect has three main steps:
1. Download and install Bito AI Architect
2. Configuring repositories to index
3. Start the indexing process

Once the indexing is complete, you can configure AI Architect MCP server in any coding or chat agent that supports MCP. This guide will walk you through installing and setting up AI Architect in a self-hosted environment.  

### Step 1- Install AI Architect

Before proceeding with the installation, ensure **Docker Desktop / Docker Service** or **Kubernetes cluster** is running on your system. If it's not already running, launch it and wait for it to fully start before continuing.

Open your terminal:
- **Linux/macOS:** Use your standard terminal application
- **Windows (WSL2):** Launch the **Ubuntu** application from the **Start menu**

Execute the installation command:
```
curl -fsSL https://aiarchitect.bito.ai/install.sh | bash
```

The installation script will:
- Download the latest Bito AI Architect package
- Extract it to your system
- Initialize the setup process

> **Installing dependencies:** The AI Architect setup process will automatically check for required tools on your system. If any dependencies are missing (such as `jq`, which is needed for JSON processing), you'll be prompted to install them. Simply type `y` and press `Enter` to proceed with the installation.

---

### Step 2- Configuration

The setup script will guide you through configuring AI Architect with your Git provider and LLM credentials. The process is interactive and will prompt you for the necessary information step by step.

#### You'll need to provide the following details when prompted:
> Refer to the [Prerequisites section](#2-prerequisites) for details on how to obtain these.
- **Deployment type** - Choose between **Docker** or **Kubernetes** based on your infrastructure requirements
- **Bito API Key** (required) - Your Bito authentication key
- **Git provider** (required) - Choose your Git provider (GitHub, GitLab or BitBucket)
- **Git Access Token** (required) - Personal access token for your Git provider
- **Enterprise Git provider domain URL** - Provide your custom domain URL if you are using enterprise/self-hosted version of Git provider (e.g., https://github.company.com).
- **LLM Keys** (required unless you have a Bito Enterprise Plan) - We suggest you provide API keys for both **Anthropic** and **Grok** LLMs for the best cost and coverage.
- **Generate a secure MCP access token?** - Type `y` to generate a secure access token (recommended)

> **LLM Rate Limit Requirements:** To ensure stable and uninterrupted operation, the configured LLM provider must support the following minimum rate limits:
>   - **Requests Per Minute (RPM):** 300
>   - **Tokens Per Minute (TPM):** 1,000,000 (1M)

---

### Step 3- Add repositories

Once your Git account is connected successfully, Bito automatically detects your repositories and populates the `/usr/local/etc/bitoarch/.bitoarch-config.yaml` file with an initial list. Review this file to confirm which repositories you want to index — feel free to remove any that should be excluded or add others as needed. Once the list looks correct, save the file, and continue with the steps below.

> For versions older than 1.4.0, configuration file can be found in installation directory.

Below is an example of how the `.bitoarch-config.yaml` file is structured:

```yaml
repository:
  configured_repos:
    - namespace: your-org/repo-name-1
    - namespace: your-org/repo-name-2
    - namespace: your-org/repo-name-3
```

After updating the `.bitoarch-config.yaml` file, you have two options to proceed with adding your repositories for indexing:

1. **Auto Configure (recommended)**
   - Automatically saves the repositories and starts indexing
   - If needed, edit the repo list before selecting this option

2. **Manual Setup**
   - You have to manually update the configuration file and then start the indexing. Below we have provided complete details of the manual process.

Once you select an option, your **Bito MCP URL** and **Bito MCP Access Token** will be displayed. Make sure to store them in a safe place, you'll need them later when configuring MCP server in your AI coding agent (e.g., Claude Code, Cursor, Windsurf, GitHub Copilot (VS Code), etc.).

To manually apply the configuration, run this command:

```bash
bitoarch add-repos /usr/local/etc/bitoarch/.bitoarch-config.yaml
```
---

### Step 4- Start indexing

Once your repositories are configured, AI Architect needs to analyze and index them to build the knowledge graph. This process scans your codebase structure, dependencies, and relationships to enable context-aware AI assistance.

Start the indexing process by running:

```bash
bitoarch index-repos
```

> The indexing process will take approximately 3-10 minutes per repository. Smaller repos take less time.

Once the indexing is complete, you can configure AI Architect MCP server in any coding or chat agent that supports MCP.

---

### Step 5- Check indexing status

Run this command to check the status of your indexing:

```bash
bitoarch index-status
```

**Example output:**

```
Configured Repositories

  Configured: 1
  Note: Config can change while an index session is running.

Index Status (Repo-level)

  State: ✓ success
  Progress: 1 / 1 completed

Index Status (Cross-Repo)

  State: ✓ success
```

**What each section represents:**

- **Configured Repositories:** Shows how many repositories are added in your config file for indexing.
- **Index Status (Repo-level):** Shows the indexing progress for each individual repository.
- **Index Status (Cross-Repo):** Shows the status of indexes that combine and process information across multiple repositories.
- **Overall Status:** Provides a single summary indicating whether indexing is still running, completed successfully, or failed.

---

### Step 6- Check MCP server details

To manually check the MCP server details (e.g. **Bito MCP URL** and **Bito MCP Access Token**), use the following command:

```bash
bitoarch mcp-info
```

If you need to update your **Bito MCP Access Token**, use the following command:

```bash
bitoarch rotate-mcp-token <new-token>
```

> Replace `<new-token>` with your new secure token value.
> **Important:** After rotating the token, you'll need to update it in all AI coding agents (Claude Code, Cursor, Windsurf, etc.) where you've configured this MCP server.

> You will need to ensure the AI Architect server is accessible over HTTPS if it is set up for team use.

---

<br />

<!-- Update repository list and re-index -->

## 4. Update repository list and re-index

You can update the repository list and re-index anytime after the initial setup through `.bitoarch-config.yaml` file.

Edit `/usr/local/etc/bitoarch/.bitoarch-config.yaml` file to add/remove repositories:

```bash
vim /usr/local/etc/bitoarch/.bitoarch-config.yaml
```

To apply the changes, run this command:

```bash
bitoarch update-repos /usr/local/etc/bitoarch/.bitoarch-config.yaml
```

Start the re-indexing process using this command:

```bash
bitoarch index-repos
```

---

<br />

<!-- Setting up AI Architect MCP in coding agents -->

## 5. Setting up AI Architect MCP in coding agents

Now that AI Architect is installed and your repositories are indexed, the next step is to connect it to your AI coding tools (such as Claude Code, Cursor, Windsurf, GitHub Copilot, etc.) through the Model Context Protocol (MCP).

### Quick setup (recommended)
**Save time with our automated installer!** We provide a one-command setup that automatically configures AI Architect for all compatible AI coding tools on your system.

The automated installer will:

- Detect all supported AI tools installed on your system
- Configure them automatically with your MCP credentials
- Get you up and running in seconds instead of manually configuring each tool

👉 [Try our Quick MCP Integration Guide](https://docs.bito.ai/ai-architect/quick-mcp-integration-with-ai-coding-agents) for automated setup across all your tools.

### Manual setup
If you prefer hands-on control over your configuration or encounter issues with automated setup, we provide detailed step-by-step guides for each supported AI coding tool:

- [Guide for Claude Code](https://docs.bito.ai/ai-architect/guide-for-claude-code)
- [Guide for Claude Desktop](https://docs.bito.ai/ai-architect/guide-for-claude-desktop)
- [Guide for Claude.ai (Web)](https://docs.bito.ai/ai-architect/guide-for-claude.ai-web)
- [Guide for Cursor](https://docs.bito.ai/ai-architect/guide-for-cursor)
- [Guide for Windsurf](https://docs.bito.ai/ai-architect/guide-for-windsurf)
- [Guide for GitHub Copilot (VS Code)](https://docs.bito.ai/ai-architect/guide-for-github-copilot-vs-code)
- [Guide for Junie (JetBrains)](https://docs.bito.ai/ai-architect/guide-for-junie-jetbrains)
- [Guide for JetBrains AI Assistant](https://docs.bito.ai/ai-architect/guide-for-jetbrains-ai-assistant)
- [Guide for ChatGPT (Web & Desktop)](https://docs.bito.ai/ai-architect/guide-for-chatgpt-web-and-desktop)

---

<br />

<!-- Configuring AI Architect for Bito AI Code Review Agent -->

## 6. Configuring AI Architect for Bito AI Code Review Agent

Now that you have **AI Architect** set up, you can take your code quality to the next level by integrating it with **[Bito's AI Code Review Agent](https://bito.ai/product/ai-code-review-agent/)**. This powerful combination delivers significantly more accurate and context-aware code reviews by leveraging the deep codebase knowledge graph that AI Architect has built.

**Why integrate AI Architect with AI Code Review Agent?**

When the AI Code Review Agent has access to AI Architect's knowledge graph, it gains a comprehensive understanding of your entire codebase architecture — including microservices, modules, APIs, dependencies, and design patterns.

This enables the AI Code Review Agent to:

- **Provide system-aware code reviews** - Understand how changes in one service or module impact other parts of your system
- **Catch architectural inconsistencies** - Identify when new code doesn't align with your established patterns and conventions
- **Detect cross-repository issues** - Spot problems that span multiple repositories or services
- **Deliver more accurate suggestions** - Generate fixes that are grounded in your actual codebase structure and usage patterns
- **Reduce false positives** - Better understand context to avoid flagging valid code as problematic

### Getting started with AI Architect-powered code reviews

1. Log in to **[Bito Cloud](https://alpha.bito.ai/home/welcome)**
2. Open the **[AI Architect Settings](https://alpha.bito.ai/home/ai-architect/settings?mode=self-hosted)** dashboard.
3. In the **Server URL** field, enter your **Bito MCP URL**
4. In the **Auth token** field, enter your **Bito MCP Access Token**

**Need help getting started?** Contact our team at **[support@bito.ai](mailto:support@bito.ai)** to request a trial. We'll help you configure the integration and get your team up and running quickly.

---

<br />

<!-- Command reference -->

## 7. Command reference

Quick reference to CLI commands for managing Bito's AI Architect.

**Note:** After installation of AI Architect, the `bitoarch` command is available globally.

**Note:** For more details, refer to [Available commands](https://docs.bito.ai/ai-architect/available-commands).

### Core operations

| Command | Description | Example |
|---------|-------------|---------|
| `bitoarch index-repos` | Trigger workspace repository indexing | Simple index without parameters |
| `bitoarch index-status` | Check indexing status | View progress and state |
| `bitoarch pause-indexing` | Pause ongoing indexing process | `bitoarch pause-indexing` |
| `bitoarch resume-indexing` | Resume paused indexing process | `bitoarch resume-indexing` |
| `bitoarch stop-indexing` | Stop indexing completely | `bitoarch stop-indexing` |
| `bitoarch index-repo-list` | List all repositories | `bitoarch index-repo-list --status active` |
| `bitoarch show-config` | Show current configuration | `bitoarch show-config --raw` |

### Repository management

| Command | Description | Example |
|---------|-------------|---------|
| `bitoarch add-repo <namespace>` | Add single repository | `bitoarch add-repo myorg/myrepo` |
| `bitoarch remove-repo <namespace>` | Remove repository | `bitoarch remove-repo myorg/myrepo` |
| `bitoarch add-repos <file>` | Load configuration from YAML | `bitoarch add-repos /usr/local/etc/bitoarch/.bitoarch-config.yaml` |
| `bitoarch update-repos <file>` | Update configuration from YAML | `bitoarch update-repos /usr/local/etc/bitoarch/.bitoarch-config.yaml` |
| `bitoarch repo-info <name>` | Get detailed repository info | `bitoarch repo-info myrepo --dependencies` |

### Service operations

| Command | Description | Example |
|---------|-------------|---------|
| `bitoarch status` | View all services status | Docker ps-like output |
| `bitoarch health` | Check health of all services | `bitoarch health --verbose` |

### Configuration

| Command | Description | Example |
|---------|-------------|---------|
| `bitoarch update-api-key` | Update Bito API key | Interactive or with --api-key flag |
| `bitoarch update-git-creds` | Update Git provider credentials | Interactive or with flags |
| `bitoarch rotate-mcp-token` | Rotate MCP access token | `bitoarch rotate-mcp-token <new-token>` |

### MCP operations

| Command | Description | Example |
|---------|-------------|---------|
| `bitoarch mcp-test` | Test MCP connection | Verify server connectivity |
| `bitoarch mcp-tools` | List available MCP tools | `bitoarch mcp-tools --details` |
| `bitoarch mcp-capabilities` | Show MCP server capabilities | `bitoarch mcp-capabilities --output caps.json` |
| `bitoarch mcp-resources` | List MCP resources | View available data sources |
| `bitoarch mcp-info` | Show MCP configuration | Display URL and token info |

### Output options

Add these flags to any command:

| Flag | Purpose | Example |
|------|---------|---------|
| `--format json` | JSON output | For automation/scripts |
| `--raw` | Show full API response | For debugging |
| `--output json` | Filtered JSON output | For index-status |
| `--help` | Show command help | Get usage information |

### Getting help

| Command | Shows |
|---------|-------|
| `bitoarch --help` | Main menu with all commands |
| `bitoarch <command> --help` | Command-specific help |

### Version

Check CLI version:

```bash
bitoarch --version
```

---

<br />

<!-- Troubleshooting guide -->

## 8. Troubleshooting guide

```bash
# Check all services
bitoarch status
bitoarch health --verbose

# View full configuration
bitoarch show-config --raw

# Test MCP connection
bitoarch mcp-test

# Check indexing status with details
bitoarch index-status --raw

# Check setup log
tail -f setup.log

# Reset installation (removes all data and configuration)
./setup.sh --clean

# Then run setup again
./setup.sh

# To stop all the service
./setup.sh --stop

# Restart service (for env based config updates)
./setup.sh --restart

# Force pull latest images and restart services
./setup.sh --update
```

---


## 9. Upgrading AI Architect

[](#overview)

Upgrade your AI Architect installation to the latest version while preserving your data and configuration.
The upgrade process:
*   Automatically detects your current version
*   Downloads and extracts the new version
*   Migrates your configuration and data
*   Seamlessly transitions to the new version
*   Preserves all indexed repositories and settings

### Upgrade instructions

### Option 1: Upgrade from within your installation (Recommended)

[](#option-1-upgrade-from-within-your-installation-recommended)

If you're running **version 1.1.0 or higher**, navigate to your current installation directory and run:

```bash
cd /path/to/bito-ai-architect
./scripts/upgrade.sh --version=latest
```

* * *

### Option 2: Upgrade from external location

[](#option-3-upgrade-from-external-location)

If you need to run the upgrade from outside your installation directory (useful for **version 1.0.0**), use the `--old-path` parameter:

```bash
# Download the standalone upgrade script
curl -O https://github.com/gitbito/ai-architect/blob/main/upgrade.sh
chmod +x upgrade.sh

# Run upgrade with explicit path
./upgrade.sh --old-path=/path/to/bito-ai-architect --version=latest
```

* * *

### Upgrade parameters
The upgrade script supports the following parameters:

```bash
# Description
--version=VERSION

# Upgrade to specific version
--version=latest

# Upgrade from custom URL or file
--url=file:///path/to/package.tar.gz

# Specify installation path (required if running outside installation directory)
--old-path=/opt/bito-ai-architect

# Show help message
--help
```


>**Your data is safe:**
> All repositories, indexes, API keys, and settings are automatically preserved during upgrade.

* * *

### Deployment type compatibility

Upgrades must be performed within the same deployment type. You can only upgrade Docker to Docker or Kubernetes to Kubernetes.

To switch between deployment types (Docker to Kubernetes or Kubernetes to Docker), you must use the `--clean` command to remove all data and configuration, then perform a fresh installation with the desired deployment type.

```bash
./setup.sh --clean
./setup.sh
```

> **Important:** Switching deployment types with `--clean` will result in data loss. All indexed repositories and configuration will be removed.

> **Note:** Kubernetes deployment support is available from version 1.3.0 onwards. Versions prior to 1.3.0 only support Docker deployment.

* * *

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
