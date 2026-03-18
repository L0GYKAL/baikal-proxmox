# Baikal + InfCloud Proxmox Helper Script

One-command installer for [Baikal](https://sabre.io/baikal/) (CalDAV/CardDAV) and [InfCloud](https://www.inf-it.com/open-source/clients/infcloud/) (web UI) on Proxmox VE.

No Docker required. Everything runs natively inside a single LXC.

## Architecture

```
Central Caddy (separate LXC)
  ├── /baikal/*          → Baikal LXC:80 (CalDAV/CardDAV + Admin)
  ├── /infcloud/*        → Baikal LXC:81 (Web UI)
  ├── /.well-known/cal*  → redirect to /baikal/dav.php
  └── /other-service/*   → Other LXC:PORT

Baikal LXC (created by this script)
  └── nginx
        ├── :80 → Baikal (PHP-FPM + SQLite)
        └── :81 → InfCloud (static files)
```

## Install

On your Proxmox host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/L0GYKAL/baikal-proxmox/main/ct/baikal-docker.sh)"
```

This automatically:
- Creates a Debian 12 LXC container
- Installs nginx + PHP-FPM
- Deploys Baikal from the latest GitHub release
- Downloads and configures InfCloud
- Outputs the LXC IP address

## Default Resources

| Resource | Value |
|----------|-------|
| CPU | 1 core |
| RAM | 256 MB |
| Disk | 2 GB |
| OS | Debian 12 |
| Privileged | No |

## Central Caddy Configuration

This script does **not** include a reverse proxy. You need a central Caddy instance (install via [community script](https://community-scripts.org/scripts/caddy)) to handle TLS and routing.

Add the Baikal routes to your Caddyfile. Choose one of the three options below.

### Option A — Subfolders (no domain or DNS needed)

Best for local/Tailscale access with multiple services on one Caddy. All services share one `:443` block, routed by path:

```caddyfile
:443 {
    tls internal

    # Baikal CalDAV/CardDAV
    redir /.well-known/caldav /baikal/dav.php permanent
    redir /.well-known/carddav /baikal/dav.php permanent

    handle /baikal/* {
        uri strip_prefix /baikal
        reverse_proxy BAIKAL_LXC_IP:80
    }

    # InfCloud web UI
    handle /infcloud/* {
        uri strip_prefix /infcloud
        reverse_proxy BAIKAL_LXC_IP:81
    }

    # Add more services here:
    # handle /gitea/* {
    #     uri strip_prefix /gitea
    #     reverse_proxy GITEA_LXC_IP:3000
    # }
}
```

Access via `https://CADDY_IP/baikal/`, `https://CADDY_IP/infcloud/`, etc.

### Option B — Local subdomains (requires local DNS)

If you run a local DNS server (Pi-hole, AdGuard Home) or edit `/etc/hosts` on your devices, point `*.home.lab` to your Caddy LXC IP:

```caddyfile
dav.home.lab {
    tls internal

    redir /.well-known/caldav /dav.php permanent
    redir /.well-known/carddav /dav.php permanent

    handle /infcloud/* {
        uri strip_prefix /infcloud
        reverse_proxy BAIKAL_LXC_IP:81
    }

    handle /* {
        reverse_proxy BAIKAL_LXC_IP:80
    }
}

# Add more services as separate blocks:
# git.home.lab {
#     tls internal
#     reverse_proxy GITEA_LXC_IP:3000
# }
```

### Option C — Public domain (auto HTTPS via Let's Encrypt)

If you have a domain pointed at your Caddy instance:

```caddyfile
dav.yourdomain.com {
    redir /.well-known/caldav /dav.php permanent
    redir /.well-known/carddav /dav.php permanent

    handle /infcloud/* {
        uri strip_prefix /infcloud
        reverse_proxy BAIKAL_LXC_IP:81
    }

    handle /* {
        reverse_proxy BAIKAL_LXC_IP:80
    }
}
```

Caddy auto-provisions Let's Encrypt certs — no `tls internal` needed.

### After editing

Replace `BAIKAL_LXC_IP` with the IP shown after install. Then reload:

```bash
systemctl reload caddy
```

## First-Time Setup

1. Go to `https://CADDY_IP/baikal/admin/` (Option A) or `https://dav.home.lab/admin/` (Option B/C)
2. Baikal shows a setup wizard — set an admin password and finish setup
3. In the admin panel, go to **Users and Resources** > **Add user**
4. Create your account (e.g. `john` with a password)

## Using InfCloud

Go to `https://CADDY_IP/infcloud/` and log in with the Baikal user you created.

## Connecting Devices

| Setting | Value |
|---------|-------|
| Server URL (Option A) | `https://CADDY_IP/baikal/dav.php/principals/` |
| Server URL (Option B/C) | `https://dav.home.lab/dav.php/principals/` |
| Username | Your Baikal user |
| Password | Your Baikal password |

### iPhone / iPad

Settings > Calendar > Accounts > Add Account > Other > Add CalDAV Account

### Android

Install [DAVx5](https://www.davx5.com/) > Add account > Login with URL and user name

### macOS

System Settings > Internet Accounts > Add Other > CalDAV account

### Thunderbird

Add CalDAV calendar with URL: `https://CADDY_IP/baikal/dav.php/principals/your-username/`

Most clients also support autodiscovery — just entering the server URL may be enough.

## Updating

Re-run the script from inside the container to update Baikal to the latest release:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/L0GYKAL/baikal-proxmox/main/ct/baikal-docker.sh)"
```

## Security

- Nginx blocks access to `.ht`, `.sqlite`, and `.yaml` files
- InfCloud is served as static files only — PHP execution is denied on port 81
- InfCloud connects to Baikal through the browser via your central Caddy
- No Docker daemon, no extra attack surface
- Runs in an unprivileged LXC container

## License

MIT
