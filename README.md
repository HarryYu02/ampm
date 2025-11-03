# AMPM

A minimal package manager. It only build from source so it's very slow.
Requires basic knowledge of using the terminal.

## Why?

I am just sick and tired of package managers hell... the breaking point for me
is when I installed homebrew for system packages, bob for nvim version control,
lazy.nvim for nvim packages, Mason for lsp servers, then finally reach ts_ls -
to write some typescript project managed by pnpm, and node version manage by
nvm or mise... The amount of package managers can form a Fortune 500 Mega Corp.
ffs.

In my use cases, I only need 2:
1. For system wide, build from source, manages versions.
2. For project wide, isolated for distribution.

No. 2 is not what I want but it's a neccessary evil I guess. But the goal of
ampm is to become my personal system pm. It's more like automating building and
linking instead of a black box that does everything for me.

## Installtion

1. Build from source:

requires zig 0.15+

```bash
git clone https://github.com/HarryYu02/ampm.git
cd ampm
zig build
./zig-out/bin/ampm --version
```

## Usage

```bash
ampm --version
ampm [command] [package]
```

- install [package]
- uninstall [package]

## Todo

- cli: read config file
- ampm install: link man pages
- ampm install: generate completion
- ampm install: checksum
- ampm install: resolve dependencies
- ampm search
- ampm info
- ampm list
- ampm exec
- ampm cleanup
- ampm update
