# Push Git Tag

Push the exact state of the app (excluding Screenshots folder) with a tag.

## Quick Command

```bash
git add -A && git commit -m "Snapshot" && git tag v$(date +%Y%m%d-%H%M%S) && git push origin main --tags
```

## Step by Step

### 1. Stage all changes
```bash
git add -A
```

### 2. Commit
```bash
git commit -m "Your message here"
```

### 3. Create a tag
```bash
git tag v1.0.0
```
Or with a timestamp:
```bash
git tag v$(date +%Y%m%d-%H%M%S)
```

### 4. Push commit and tag
```bash
git push origin main --tags
```

## Notes

- The `Screenshots/` folder is excluded via `.gitignore`
- Tags are immutable snapshots of your code at that point in time
- Use `git tag` to list all tags
- Use `git show <tag>` to view tag details
