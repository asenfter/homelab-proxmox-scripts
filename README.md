# homelab-proxmox-scrips

Small Proxmox VE bootstrap scripts for Docker-based GitHub Actions deployment runners.

## Docker Runner LXC

This repository extends the Community Scripts GitHub Runner pattern with a small Docker deployment layer:

- Debian 13 LXC
- unprivileged container
- nesting + keyctl
- GitHub Actions self-hosted runner
- Docker Engine from Docker's official Debian repository
- Docker Compose plugin
- Docker access for the existing `runner` user
- `/opt/homelab` deployment checkout directory

Application stacks such as Beszel, LiteLLM, OpenHAB, and Grafana are deployed separately through GitHub Actions and Docker Compose.

## Structure

```text
homelab-proxmox-scripts/
├── LICENSE
├── README.md
├── ct/
│   └── docker-runner.sh
└── install/
    └── docker-runner-install.sh
```

The split intentionally follows the Community Scripts structure. `ct/docker-runner.sh` defines the LXC and update behaviour; `install/docker-runner-install.sh` provisions the software inside it.

`APP="Docker-Runner"` is load-bearing because Community Scripts uses it to resolve `install/docker-runner-install.sh`.

## Install

Run from the Proxmox VE host shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asenfter/homelab-proxmox-scripts/main/ct/docker-runner.sh)"
```

To override the container defaults (2 CPU, 2048 MiB, 20 GB), prefix the command with the corresponding `var_*` variables and select `Default Install` in the menu:

```bash
var_hostname=ci-runner \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/asenfter/homelab-proxmox-scripts/main/ct/docker-runner.sh)"
```

The variables must precede `bash`, not `curl`. Community Scripts Core reads them in `base_settings()`, so no interactive wizard is required for these four values.

The script uses Community Scripts Core at runtime. `COMMUNITY_SCRIPTS_URL` explicitly points to this repository so the matching installer and CT update entrypoint come from this fork.

## Register the GitHub runner

After the LXC has been created:

```bash
su - runner
cd /opt/actions-runner
```

In GitHub open `Repository -> Settings -> Actions -> Runners -> New self-hosted runner`.

Run the registration command GitHub provides and add a service-specific custom label such as `beszel`. Do not store the short-lived registration token in this repository.

Then:

```bash
exit
systemctl start actions-runner
systemctl status actions-runner
```

The service unit carries `ConditionPathExists=/opt/actions-runner/.runner`, so
it stays inactive until registration has completed. Before that, `systemctl
status` reports a failed condition rather than a restart loop. This is
expected.

## Deployment directory

The bootstrap creates `/opt/homelab`, owned by `runner`.

Repository authentication and the initial homelab checkout are deliberately not configured here. This public repository must not contain PATs, GitHub App credentials, deployment secrets, or application secrets.

## Updates

The CT update function runs inside the LXC. It uses the Community Scripts OS update helper, so Docker and Compose are updated through Docker's Debian APT repository. It also checks GitHub for a newer Actions Runner release and preserves the registered runner configuration while replacing runner binaries.

A runner update replaces `/opt/actions-runner` completely, which also removes
`/opt/actions-runner/_work`. Workflow checkouts and caches under `_work` are
discarded and rebuilt on the next run. The deployment directory `/opt/homelab`
lies outside that path and is not affected.

Application containers remain outside this lifecycle:

```text
LXC OS / Docker / Compose  -> Community Scripts OS/package update
GitHub Actions Runner      -> GitHub release update
Beszel / LiteLLM / etc.    -> Git commit -> GitHub Actions -> Docker Compose
```

## Security and supply chain

Membership in the `docker` group effectively grants root-level control over the LXC. Treat these runners as trusted deployment infrastructure and do not run untrusted pull-request workloads on them.

This repository intentionally follows the Community Scripts model and currently consumes Community Scripts Core from its `main` branch. Docker packages come from Docker's official Debian APT repository and Actions Runner binaries from GitHub releases.

The public install command also downloads this repository's `main` branch. This is convenient for a homelab but is not a fully pinned supply chain. A future hardening step can pin the bootstrap/Core to reviewed commits or tags.

## Upstream and dependency

This project is based directly on the GitHub Runner LXC from [Proxmox VE Helper-Scripts / Community Scripts](https://github.com/community-scripts/ProxmoxVE).

Upstream implementation:

- [GitHub Runner LXC (`ct/github-runner.sh`)](https://github.com/community-scripts/ProxmoxVE/blob/main/ct/github-runner.sh)
- [GitHub Runner installation (`install/github-runner-install.sh`)](https://github.com/community-scripts/ProxmoxVE/blob/main/install/github-runner-install.sh)
- [Community Scripts Core](https://github.com/community-scripts/core)

This project intentionally uses Community Scripts Core at runtime. It is not a standalone replacement for Community Scripts.

The original copyright and MIT license notice are retained. This repository is an independent derivative project and is not affiliated with or maintained by community-scripts ORG.
