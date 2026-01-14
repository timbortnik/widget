# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by:

1. **Do NOT open a public issue** - this could put users at risk
2. **Email the maintainer directly** or use GitHub's [Security Advisory](https://github.com/YOUR_USERNAME/YOUR_REPO/security/advisories/new) feature
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We aim to respond to security reports within **48 hours** and provide a fix within **7 days** for high-severity issues.

## Security Measures

### Dependency Management

- **Automated scanning**: Dependabot monitors dependencies weekly
- **Pinned versions**: Critical dependencies (like `home_widget`) are pinned for stability
- **Regular updates**: Dependencies are reviewed and updated monthly
- **Vulnerability tracking**: All dependencies checked against [GitHub Advisory Database](https://github.com/advisories)

### Code Security

- **Static analysis**: `flutter analyze` runs on all commits via CI/CD
- **CodeQL scanning**: Advanced security analysis on Java/Kotlin Android code
- **Test coverage**: Automated tests verify core functionality
- **No secrets in code**: API keys and sensitive data are never committed

### Build Security

- **Signed releases**: All release APKs are signed
- **Minimal permissions**: App requests only necessary Android permissions
- **Secure defaults**: Berlin fallback location (no IP geolocation tracking)
- **Data privacy**: No telemetry, no user tracking, no data collection

### Third-Party Services

This app uses these third-party services:

| Service | Purpose | Data Shared | Privacy Policy |
|---------|---------|-------------|----------------|
| [Open-Meteo](https://open-meteo.com/) | Weather data API | GPS coordinates | [Privacy Policy](https://open-meteo.com/en/terms) |
| Native platform services | GPS, geocoding | Location data (stays on device) | Per Android/iOS policies |

**No API keys required** - Open-Meteo is a free public API with no registration.

## Known Security Considerations

### home_widget Version Pin

This project intentionally uses `home_widget: 0.8.0` (not latest 0.9.0) due to functional issues with widget resizing. See [docs/HOME_WIDGET_VERSION_ISSUE.md](docs/HOME_WIDGET_VERSION_ISSUE.md) for details.

**Security impact**: `JobIntentService` (used in 0.8.0) is deprecated but still functional and secure. We monitor for security advisories and will migrate when 0.9.0+ fixes the resize issue.

### Permissions

The app requests these Android permissions:

- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` - Optional, for GPS weather
- `INTERNET` - Required for weather API
- `ACCESS_NETWORK_STATE` - For offline detection

**Fallback behavior**: If GPS is denied, the app defaults to Berlin coordinates. No location data is sent anywhere except the weather API (Open-Meteo).

## Security Best Practices for Contributors

1. **Never commit secrets**: No API keys, tokens, or credentials in code
2. **Validate user input**: All user input must be sanitized (city search, coordinates)
3. **Use parameterized queries**: No string concatenation for URLs/SQL
4. **Follow least privilege**: Request minimum necessary permissions
5. **Test edge cases**: Null checks, bounds checking, error handling
6. **Review dependencies**: Check new dependencies for known vulnerabilities
7. **Sign commits**: Use GPG-signed commits for release branches

## Vulnerability Disclosure Timeline

1. **Day 0**: Vulnerability reported privately
2. **Day 1-2**: Maintainer acknowledges report
3. **Day 3-7**: Fix developed and tested
4. **Day 7-14**: Security patch released
5. **Day 14+**: Public disclosure (after users can update)

## Security Contacts

- **Project Maintainer**: [GitHub Issues](https://github.com/YOUR_USERNAME/meteogram-widget/issues) (for non-security issues)
- **Security Reports**: Use [GitHub Security Advisories](https://github.com/YOUR_USERNAME/meteogram-widget/security/advisories/new)

## Acknowledgments

We appreciate security researchers who responsibly disclose vulnerabilities. Contributors will be credited in release notes (unless they prefer anonymity).

---

**Last Updated**: 2026-01-14
