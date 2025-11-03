# AMPM

A minimal package manager. It only build from source so it's very slow.

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
