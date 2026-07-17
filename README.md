# Nakumi Sync

Full fresh installation plus automatic delta updates for Homestead x All of
Create Aeronautics. No r6 or older pack is required.

- Client old-or-new one-click installer: `Nakumi-Sync-Setup.cmd`
- Crafty Windows startup command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "iex (irm 'https://bayusegara27.github.io/nakumi-sync/Nakumi-Sync-Server-Windows.ps1')"
```

- Linux startup command:

```sh
curl -fsSL https://bayusegara27.github.io/nakumi-sync/Nakumi-Sync-Server-Start.sh | bash
```

Official mods are downloaded from the official Modrinth CDN. This repository
hosts only Packwiz metadata, reviewed configuration files, bootstrap scripts,
and the small custom TAB build.

New installations download the immutable complete baseline from the GitHub
Release `r9.3-full`, verify its SHA-256, and then apply the current channel.
Existing installations skip the full snapshot. The server command is intended
for Crafty on Windows and must run from the server root.
