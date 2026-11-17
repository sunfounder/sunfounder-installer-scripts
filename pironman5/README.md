# Pironman 5 Installer (deprecated)

**This directory is deprecated.** The Pironman 5 installer lives with the product, on the current `v1` branch of that repository (`1.3.x` is deprecated):

```bash
curl -sSL "https://raw.githubusercontent.com/sunfounder/pironman5/v1/install.sh" | sudo bash
# China mirror
curl -sSL "https://gitee.com/sunfounder/pironman5/raw/v1/install.sh" | sudo bash -s -- --cn
```

- Product repository: <https://github.com/sunfounder/pironman5>
- Variants, flags and troubleshooting: see that repository's `README.md`.

## Why is this still here?

`pironman5 update` on released versions still downloads
`pironman5/install.sh` from this repository. `install.sh` here is now a thin
forwarder: it prints a deprecation notice, downloads the product installer from
the URL above and runs it with the same arguments. It carries no logic of its
own, so it cannot drift from the real installer again.

Because the forwarder points at `v1`, an installation that was still on
`1.3.x` is moved to the current line when it runs `pironman5 update`.

The `Dockerfile` in this directory still builds with the forwarder and the
framework in `tools/`.

## Repository policy

Installers belong in the repository of the product they install. This
repository keeps shared tooling (`tools/`, used by the product installers) and
installers for products that have no repository of their own.
