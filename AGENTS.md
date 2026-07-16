# Workflow Tools

This repository contains personal tool configuration tracked in Git and symlinked into `~/.config` by `setup-symlinks.sh`.

## Repository Structure
- `nvim/` is the source Neovim configuration, symlinked to `~/.config/nvim`.
- `tmux/` is the source tmux configuration, symlinked to `~/.config/tmux`.
- `AGENTS.global.md` contains personal OpenCode rules, symlinked to `~/.config/opencode/AGENTS.md`.
- `skills/` contains personal OpenCode skills.

## Conventions
- Edit the tracked source files in this repository, not their symlinked destinations.
- Keep `setup-symlinks.sh` idempotent when adding or changing symlinks.
