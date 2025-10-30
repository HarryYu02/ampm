# AMPM

A minimal package manager.

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
ampm [command] [package]
```

- install [package]
- uninstall [package]

## Todo

- version
- link man pages
- checksum
- resolve dependencies
