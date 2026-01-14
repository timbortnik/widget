# GitHub Security Setup Guide

This guide explains how to enable automatic vulnerability scanning for this repository.

## Quick Start

**Files Created:**
- `.github/dependabot.yml` - Dependency update automation
- `.github/workflows/security.yml` - Security scanning workflow
- `SECURITY.md` - Security policy and vulnerability reporting

**To Enable:**
1. Push these files to GitHub
2. Enable security features in repository settings (see below)
3. Review and merge Dependabot PRs as they arrive

---

## 1. Enable Dependabot (Automatic)

Dependabot is **enabled by default** when you push `.github/dependabot.yml`. It will:

✅ **Scan dependencies weekly** for known vulnerabilities
✅ **Create PRs automatically** to update vulnerable packages
✅ **Respect ignore rules** (e.g., `home_widget` stays pinned)
✅ **Group updates** to reduce PR noise

**What to expect:**
- First scan runs within 24 hours of pushing the config
- Weekly scans every Monday at 9 AM (Europe/Kiev time)
- PRs labeled with `dependencies` and `security`

**Manual trigger:**
```bash
# Go to: Settings > Code security > Dependency graph > Dependabot
# Click "Check for updates" to trigger immediately
```

---

## 2. Enable Dependency Review (Pull Requests)

Prevents merging PRs that introduce vulnerable dependencies.

**Steps:**
1. Go to: **Settings** → **Code security and analysis**
2. Enable **Dependency graph** (should be on by default)
3. Enable **Dependabot alerts**
4. Enable **Dependabot security updates**

**What it does:**
- Blocks PRs with high/critical vulnerabilities
- Shows vulnerability details in PR checks
- Configured in `.github/workflows/security.yml` (dependency-review job)

---

## 3. Enable CodeQL Analysis (Advanced)

Scans Java/Kotlin Android code for security vulnerabilities.

**Steps:**
1. Go to: **Settings** → **Code security and analysis**
2. Enable **Code scanning** → **Set up** → **Default**
3. Or manually enable **CodeQL analysis**

**What it scans:**
- SQL injection, XSS, command injection
- Insecure cryptography, weak randomness
- Path traversal, resource leaks
- Android-specific vulnerabilities (intents, permissions)

**When it runs:**
- Every push to `main`
- All pull requests
- Weekly scheduled scan (Mondays)
- Manual trigger via Actions tab

**Results:** Settings → Security → Code scanning alerts

---

## 4. Enable Secret Scanning

Prevents accidental commit of API keys, tokens, passwords.

**Steps:**
1. Go to: **Settings** → **Code security and analysis**
2. Enable **Secret scanning**
3. Enable **Push protection** (blocks commits with secrets)

**What it detects:**
- API keys (AWS, Google, GitHub, etc.)
- Private keys (RSA, SSH)
- Database credentials
- OAuth tokens

**Note:** This project has no API keys (uses free Open-Meteo API).

---

## 5. Configure Branch Protection

Require security checks before merging to `main`.

**Steps:**
1. Go to: **Settings** → **Branches**
2. Add rule for `main` branch
3. Enable:
   - ✅ **Require a pull request before merging**
   - ✅ **Require status checks to pass**
     - Select: `Flutter Analyze & Test`
     - Select: `Dependency Review` (if enabled)
     - Select: `CodeQL` (if enabled)
   - ✅ **Require conversation resolution before merging**

**Optional but recommended:**
- Require signed commits
- Require linear history

---

## 6. Enable Security Advisories

Allow private vulnerability reporting.

**Steps:**
1. Go to: **Settings** → **Code security and analysis**
2. Enable **Private vulnerability reporting**

**What it does:**
- Users can report vulnerabilities privately
- You get notified immediately
- Work on fix before public disclosure
- Publish security advisory when ready

**Report URL:** `https://github.com/YOUR_USERNAME/meteogram-widget/security/advisories/new`

---

## 7. Review Security Alerts

**Check regularly:**
```
Repository → Security tab
├── Dependabot alerts (vulnerable dependencies)
├── Code scanning alerts (CodeQL findings)
└── Secret scanning alerts (leaked credentials)
```

**Email notifications:** GitHub emails you when new alerts appear.

---

## Monitoring & Maintenance

### Weekly Tasks (Automated)
- Dependabot scans dependencies
- CodeQL scans codebase
- GitHub Actions runs tests

### Monthly Tasks (Manual)
1. Review open Dependabot PRs
2. Check Security tab for new alerts
3. Run: `flutter pub outdated` locally
4. Update pinned dependencies if needed

### When Dependabot Creates a PR
1. **Review the PR**: Check changelog, breaking changes
2. **Check CI**: Ensure tests pass
3. **Test locally** (optional but recommended):
   ```bash
   git checkout dependabot/pub/package-name-1.2.3
   flutter pub get
   flutter analyze
   flutter test
   make install-debug  # Test on emulator
   ```
4. **Merge or close**: Merge if safe, close if breaks functionality

---

## Special Case: home_widget

This project intentionally pins `home_widget: 0.8.0` due to a functional regression in 0.9.0+. See [docs/HOME_WIDGET_VERSION_ISSUE.md](HOME_WIDGET_VERSION_ISSUE.md).

**Dependabot configuration:**
```yaml
ignore:
  - dependency-name: "home_widget"
    # Pinned to 0.8.0 - see HOME_WIDGET_VERSION_ISSUE.md
```

**If Dependabot suggests home_widget update:**
1. Check if 0.9.0+ fixed the WorkManager delay issue
2. Test widget resize on physical device
3. Only merge if resize works immediately

---

## Security Scanning Results

**Current Status (as of 2026-01-14):**
- ✅ No known vulnerabilities in dependencies
- ✅ `shared_preferences_android` 2.4.18 (patched, CVE fixed)
- ✅ `http` 1.6.0 (patched, header injection fixed)
- ✅ No secrets detected
- ✅ Flutter analyzer: 0 issues

---

## Troubleshooting

### "Dependabot not creating PRs"
- Check: Settings → Code security → Dependency graph (must be enabled)
- Check: `.github/dependabot.yml` syntax (use YAML validator)
- Wait: First scan takes up to 24 hours

### "CodeQL workflow failing"
- Ensure Java 17 is available (workflow uses temurin distribution)
- Check APK build succeeds: `flutter build apk --debug`
- Review workflow logs in Actions tab

### "Too many Dependabot PRs"
- Adjust `open-pull-requests-limit` in `dependabot.yml`
- Use `groups` to combine minor/patch updates
- Set schedule to `monthly` instead of `weekly`

### "Dependabot updating pinned dependency"
- Add to `ignore` list in `dependabot.yml`
- Example already included for `home_widget`

---

## Resources

- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [CodeQL Documentation](https://codeql.github.com/docs/)
- [GitHub Security Features](https://docs.github.com/en/code-security)
- [Dart Security Advisories](https://dart.dev/tools/pub/security-advisories)
- [GitHub Advisory Database](https://github.com/advisories?query=ecosystem:pub)

---

## Questions?

Open an issue or check the [SECURITY.md](../SECURITY.md) file for vulnerability reporting.
