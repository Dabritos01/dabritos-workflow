# Personal Rules

## Working Style
- Always present a plan before making changes. Wait for approval before building.
- Keep explanations minimal. Focus on code, not prose.

## General
- Never read or explore generated/dependency directories (node_modules, dist, build, .next, out) unless explicitly asked.
- Do not create unnecessary files (especially READMEs or docs unless asked).
- Prefer editing existing files over creating new ones.
- Prefer existing patterns in the codebase over introducing new ones.

## Shell Environment

`nvm` is a shell function, not a binary — it won't work in non-interactive shells.
To run node/npm/yarn commands in any project using `.nvmrc`, prefix with:

```sh
export PATH="$HOME/.nvm/versions/node/v$(cat .nvmrc)/bin:$PATH"
```

Example:
```sh
export PATH="$HOME/.nvm/versions/node/v$(cat .nvmrc)/bin:$PATH" && yarn why -R <package>
```

Do NOT use `nvm use &&` as a prefix — it will fail silently or error.

## Immutable Installs
- NEVER run `yarn install --no-immutable` or `yarn install --mode=update-lockfile` without explicit user approval.
- If a lockfile update is needed, STOP and ask: "The lockfile needs updating because [reason]. Can I run `yarn install --no-immutable`?"
- This applies even when changes are obviously needed (e.g., after adding a resolution or changing a dependency version).

## dh folders and \*.dh.\* files
- I have folders called dh and files containing .dh. globally git ignored
- These are scratch/working files that are safe to write to
