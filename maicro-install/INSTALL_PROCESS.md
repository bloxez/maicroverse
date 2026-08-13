# Maintaining the Install Process

The installer is maintained directly in `bloxez/maicroverse` at `maicro-install/`. There is no separate installer repository or publishing step.

## Workflow

Make changes in `maicroverse/maicro-install/`, commit them in the `maicroverse` repository, and push `main`:

```bash
cd maicroverse
git add maicro-install/
git commit -m "fix: update installer"
git push origin main
```

The public installation commands use the raw `maicroverse` URLs documented in `README.md`. Once the changes are pushed, they are available immediately.
