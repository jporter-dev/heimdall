# CI/CD Pipeline Setup Guide

This document provides instructions for setting up and configuring the GitHub Actions CI/CD pipeline for the LLM Firewall project.

## Pipeline Overview

The CI/CD pipeline consists of four main jobs that run in parallel for quality checks, followed by build/release jobs that run only on the main branch:

### Quality Assurance Jobs (Parallel)

1. **Code Linting** - Uses RuboCop with Rails Omakase styling
2. **Security Scanning** - Uses Brakeman for vulnerability detection
3. **Code Quality Analysis** - Uses SonarCloud for comprehensive code analysis

### Deployment Jobs (Sequential, Release Branches Only)

4. **Semantic Release** - Automatically versions and releases based on conventional commits
5. **Build and Push Container Image** - Builds Docker image and pushes to GHCR (only when a release is created)

## Required Setup

### 1. GitHub Repository Settings

#### Secrets Configuration

Add the following secrets in your GitHub repository settings (`Settings > Secrets and variables > Actions`):

- `SONAR_TOKEN`: SonarCloud authentication token
  - Sign up at [SonarCloud](https://sonarcloud.io/)
  - Create a new project and generate a token
  - Add the token to GitHub secrets

#### Repository Permissions

Ensure the following permissions are enabled in `Settings > Actions > General`:

- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

### 2. SonarCloud Configuration

1. **Create SonarCloud Account**

   - Visit [SonarCloud](https://sonarcloud.io/)
   - Sign in with your GitHub account
   - Import your repository

2. **Update Configuration**

   - Edit `sonar-project.properties`
   - Replace `your-github-username` with your actual GitHub username/organization
   - Adjust project settings as needed

3. **Generate Token**
   - Go to SonarCloud > My Account > Security
   - Generate a new token
   - Add it as `SONAR_TOKEN` secret in GitHub

### 3. Container Registry Setup

The pipeline automatically pushes container images to GitHub Container Registry (GHCR). No additional setup is required as it uses the built-in `GITHUB_TOKEN`.

Images will be available at: `ghcr.io/your-username/your-repo-name`

### 4. Semantic Release Configuration

The pipeline uses conventional commits for automatic versioning:

#### Commit Message Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Commit Types and Release Impact

- `feat:` → Minor version bump (new feature)
- `fix:` → Patch version bump (bug fix)
- `perf:` → Patch version bump (performance improvement)
- `refactor:` → Patch version bump (code refactoring)
- `BREAKING CHANGE:` → Major version bump
- `docs:`, `style:`, `test:`, `chore:`, `ci:`, `build:` → No release

#### Examples

```bash
# Patch release (1.0.0 → 1.0.1)
git commit -m "fix: resolve authentication timeout issue"

# Minor release (1.0.0 → 1.1.0)
git commit -m "feat: add new prompt filtering endpoint"

# Major release (1.0.0 → 2.0.0)
git commit -m "feat!: redesign API response format

BREAKING CHANGE: API responses now use different field names"
```

#### Release Branches

The pipeline supports three release branches:

- **`main`**: Production releases (e.g., `1.0.0`, `1.1.0`, `2.0.0`)
- **`beta`**: Beta pre-releases (e.g., `1.1.0-beta.1`, `1.1.0-beta.2`)
- **`alpha`**: Alpha pre-releases (e.g., `1.1.0-alpha.1`, `1.1.0-alpha.2`)

#### Release Workflow

1. **Development**: Work on feature branches
2. **Alpha Testing**: Merge to `alpha` branch for early testing
3. **Beta Testing**: Merge to `beta` branch for broader testing
4. **Production**: Merge to `main` branch for stable release

#### Pre-release Versioning

- Alpha releases: `1.1.0-alpha.1`, `1.1.0-alpha.2`, etc.
- Beta releases: `1.1.0-beta.1`, `1.1.0-beta.2`, etc.
- Production releases: `1.1.0`, `1.2.0`, etc.

## Pipeline Triggers

### Automatic Triggers

- **Push to any branch**: Runs linting, tests, and security scans
- **Pull Request to any branch**: Runs code quality analysis (SonarCloud) in addition to basic checks
- **Push to `main`, `beta`, or `alpha` branches**: Runs full pipeline including build, push, and release

### Manual Triggers

You can manually trigger the pipeline from the GitHub Actions tab.

## Pipeline Jobs Details

### 1. Code Linting (`lint`)

- **Tool**: RuboCop with Rails Omakase configuration
- **Configuration**: `.rubocop.yml`
- **Output**: GitHub-formatted annotations on PR

### 2. Security Scanning (`security`)

- **Tool**: Brakeman static analysis
- **Configuration**: Default Brakeman settings
- **Output**: JSON report uploaded as artifact
- **Failure**: Pipeline fails on security warnings

### 3. Code Quality Analysis (`code-quality`)

- **Tool**: SonarCloud
- **Configuration**: `sonar-project.properties`
- **Features**:
  - Code smells detection
  - Security hotspots
  - Code coverage analysis
  - Duplication detection
  - Maintainability rating

### 4. Semantic Release (`release`)

- **Versioning**: Automatic based on conventional commits
- **Changelog**: Auto-generated `CHANGELOG.md`
- **GitHub Release**: Created with release notes
- **Conditional Execution**: Only runs on main/beta/alpha branches
- **Outputs**: Provides release status and version for downstream jobs

### 5. Build and Push Container Image (`build-and-push`)

- **Registry**: GitHub Container Registry (GHCR)
- **Conditional Execution**: Only runs when semantic-release creates a new release
- **Tags**:
  - Release version (e.g., `1.0.0`, `1.1.0-beta.1`)
  - `latest` (main branch releases only)
- **Caching**: GitHub Actions cache for faster builds
- **Dependency**: Requires successful release job completion

## Monitoring and Troubleshooting

### Pipeline Status

- Check the Actions tab in your GitHub repository
- Each job provides detailed logs and error messages
- Failed jobs will show specific error details

### Common Issues

#### SonarCloud Authentication

```
Error: You're not authorized to run analysis
```

**Solution**: Verify `SONAR_TOKEN` secret is correctly set

#### Container Registry Permission

```
Error: denied: permission_denied
```

**Solution**: Ensure repository has write permissions for packages

#### Semantic Release No Release

```
No release published
```

**Solution**: Ensure commits follow conventional commit format

#### RuboCop Failures

```
RuboCop found offenses
```

**Solution**: Run `bundle exec rubocop -A` locally to auto-fix issues

### Viewing Results

#### Security Reports

- Download Brakeman reports from the Actions artifacts
- View security issues in the JSON report

#### Code Quality

- Visit your SonarCloud project dashboard
- Review code smells, security hotspots, and coverage

#### Container Images

- View published images in the Packages tab of your repository
- Images are publicly accessible by default

## Local Development

### Running Quality Checks Locally

```bash
# Install dependencies
bundle install

# Run linting
bundle exec rubocop

# Run security scan
bundle exec brakeman

# Run tests
bundle exec rails test

# Build container image
docker build -t llm-fw .
```

### Pre-commit Hooks (Optional)

Consider setting up pre-commit hooks to run quality checks before commits:

```bash
# Install pre-commit (requires Python)
pip install pre-commit

# Create .pre-commit-config.yaml (example)
cat > .pre-commit-config.yaml << EOF
repos:
  - repo: local
    hooks:
      - id: rubocop
        name: RuboCop
        entry: bundle exec rubocop
        language: system
        files: \.rb$
      - id: brakeman
        name: Brakeman
        entry: bundle exec brakeman --exit-on-warn
        language: system
        files: \.rb$
EOF

# Install hooks
pre-commit install
```

## Customization

### Modifying Quality Checks

- **RuboCop**: Edit `.rubocop.yml`
- **Brakeman**: Add `config/brakeman.yml` for custom configuration
- **SonarCloud**: Modify `sonar-project.properties`

### Changing Release Strategy

- **Branches**: Edit `branches` in `.releaserc.json`
- **Release Rules**: Modify `releaseRules` in `.releaserc.json`
- **Plugins**: Add/remove plugins in `.releaserc.json`

### Container Image Customization

- **Base Image**: Modify `Dockerfile`
- **Tags**: Edit metadata extraction in workflow
- **Registry**: Change `REGISTRY` environment variable

## Security Considerations

- All secrets are properly masked in logs
- Container images use non-root user
- Minimal permissions granted to GitHub Actions
- Security scanning runs on every change
- Dependency scanning via GitHub's built-in features

## Support

For issues with the pipeline:

1. Check the Actions logs for specific error messages
2. Verify all required secrets are configured
3. Ensure branch protection rules don't conflict
4. Review the troubleshooting section above

For tool-specific issues:

- **RuboCop**: [RuboCop Documentation](https://rubocop.org/)
- **Brakeman**: [Brakeman Documentation](https://brakemanscanner.org/)
- **SonarCloud**: [SonarCloud Documentation](https://docs.sonarcloud.io/)
- **Semantic Release**: [Semantic Release Documentation](https://semantic-release.gitbook.io/)
