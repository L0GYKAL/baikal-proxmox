# Baikal + InfCloud Proxmox Helper Script

One-command installer for [Baikal](https://sabre.io/baikal/) (CalDAV/CardDAV) and [InfCloud](https://www.inf-it.com/open-source/clients/infcloud/) (web UI) on Proxmox VE.

No Docker required. Everything runs natively inside a single LXC.

## Architecture

```
Central Caddy (separate LXC)
  ├── /dav.php*          → Baikal LXC:80
  ├── /admin/*           → Baikal LXC:80
  ├── /infcloud/*        → Baikal LXC:81
  ├── /.well-known/cal*  → redirect to /dav.php
  └── /*                 → Baikal LXC:80

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

This script does **not** include a reverse proxy. Add this to your central Caddy's Caddyfile:

### With a domain (auto HTTPS via Let's Encrypt)

```caddyfile
dav.yourdomain.com {
    # CalDAV/CardDAV autodiscovery (RFC 6764)
    redir /.well-known/caldav /dav.php permanent
    redir /.well-known/carddav /dav.php permanent

    # InfCloud web UI
    handle /infcloud/* {
        uri strip_prefix /infcloud
        reverse_proxy BAIKAL_LXC_IP:81
    }

    # Everything else goes to Baikal
    handle /* {
        reverse_proxy BAIKAL_LXC_IP:80
    }
}
```

### Tailscale only (no public domain)

```caddyfile
:443 {
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
```

Replace `BAIKAL_LXC_IP` with the IP shown after install. Then reload:

```bash
caddy reload --config /etc/caddy/Caddyfile
```

## First-Time Setup

1. Go to `https://yourdomain/admin/` (or `http://BAIKAL_LXC_IP` directly)
2. Baikal shows a setup wizard — set an admin password and finish setup
3. In the admin panel, go to **Users and Resources** > **Add user**
4. Create your account (e.g. `john` with a password)

## Using InfCloud

Go to `https://yourdomain/infcloud/` and log in with the Baikal user you created.

## Connecting Devices

| Setting | Value |
|---------|-------|
| Server URL | `https://yourdomain/dav.php/principals/` |
| Username | Your Baikal user |
| Password | Your Baikal password |

### iPhone / iPad

Settings > Calendar > Accounts > Add Account > Other > Add CalDAV Account

### Android

Install [DAVx5](https://www.davx5.com/) > Add account > Login with URL and user name

### macOS

System Settings > Internet Accounts > Add Other > CalDAV account

### Thunderbird

Add CalDAV calendar with URL: `https://yourdomain/dav.php/principals/your-username/`

Most clients also support autodiscovery — just entering `https://yourdomain` may be enough.

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
