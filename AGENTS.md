# Appagon DevOps

Read this file before doing anything.

This repository contains deployment tools shared by Appagon applications.

Main documents:

- docs/DEPLOYMENT.md
- docs/ADDING_APP.md
- docs/ARCHITECTURE.md

Rules:

- Never commit apps/*.env
- Never commit secrets
- Never deploy without explicit user request
- Never bypass Git checks
- Never modify production manually if Git manages the file
- Always preserve backward compatibility

## Vérification

From this repo root. Script syntax only — **never run a deploy** to verify.

```bash
bash -n scripts/deploy-django.sh
bash -n scripts/deploy-php.sh
```

If `shellcheck` is installed: `shellcheck scripts/*.sh`.
