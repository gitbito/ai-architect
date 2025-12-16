# Upgrading AI Architect

[](#upgrading-ai-architect)

Learn how to upgrade your AI Architect installation to the latest version while preserving your data and configuration.

* * *

## Overview

[](#overview)

AI Architect supports upgrades using a blue/green deployment strategy. The upgrade process:

*   Automatically detects your current version
*   Downloads and extracts the new version
*   Migrates your configuration and data
*   Seamlessly transitions to the new version
*   Preserves all indexed repositories and settings

> **⚠️ Important:** After a successful upgrade, rollback is not supported.

* * *

## Upgrade instructions

[](#upgrade-instructions)

The upgrade process varies slightly depending on your current version and how you run the upgrade script.

### Option 1: Upgrade from within your installation (Recommended)

[](#option-1-upgrade-from-within-your-installation-recommended)

If you're running **version 2.0.0 or higher**, navigate to your current installation directory and run:

```bash
cd /path/to/bito-ai-architect
./scripts/upgrade.sh --version=2.0.0
```

* * *

### Option 2: Upgrade from external location

[](#option-3-upgrade-from-external-location)

If you need to run the upgrade from outside your installation directory (useful for **version 1.0.0**), use the `--old-path` parameter:

```bash
# Download the standalone upgrade script
curl -O https://raw.githubusercontent.com/gitbito/ai-architect/main/scripts/upgrade.sh
chmod +x upgrade.sh

# Run upgrade with explicit path
./upgrade.sh --old-path=/path/to/bito-ai-architect --version=2.0.0
```

* * *

## Upgrade parameters

[](#upgrade-parameters)

The upgrade script supports the following parameters:

Parameter

Description

Example

`--version=VERSION`

Upgrade to specific version

`--version=2.0.0`

`--url=URL`

Upgrade from custom URL or file

`--url=file:///path/to/package.tar.gz`

`--old-path=PATH`

Specify installation path (required if running outside installation directory)

`--old-path=/opt/bito-ai-architect`

`--help`

Show help message

`--help`

* * *

## What gets preserved during upgrade

[](#what-gets-preserved-during-upgrade)

The upgrade process preserves:

*   ✅ All indexed repositories and knowledge graphs
*   ✅ Your Git provider credentials and access tokens
*   ✅ Bito API key and MCP access token
*   ✅ LLM API keys configuration
*   ✅ Repository configurations (`.bitoarch-config.yaml`)
*   ✅ Docker volumes containing all data
*   ✅ Service configurations and settings

* * *