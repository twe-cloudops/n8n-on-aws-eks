# Contributing to n8n-on-aws-eks

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/n8n-on-aws-eks.git
   cd n8n-on-aws-eks
   ```
3. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites
- AWS CLI configured with appropriate credentials
- kubectl (v1.28+)
- eksctl (v0.150+)
- bash 4.0+

### Configuration
1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
2. Edit `.env` with your AWS configuration
3. Never commit `.env` to version control

## Making Changes

### Code Style
- Use `set -euo pipefail` in all bash scripts
- Follow existing code formatting
- Add comments for complex logic
- Use meaningful variable names

### Testing
- Test your changes in a dev environment first
- Run existing tests: `bats tests/`
- Add tests for new functionality
- Ensure all tests pass before submitting

### Documentation
- Update README.md if adding new features
- Update CHANGELOG.md following existing format
- Add inline comments for complex code
- Update .env.example if adding new configuration options

## Submitting Changes

### Pull Request Process

1. **Update your branch** with latest main:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Commit your changes** with clear messages:
   ```bash
   git commit -m "feat: add new feature"
   git commit -m "fix: resolve issue with deployment"
   git commit -m "docs: update README"
   ```

3. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Create a Pull Request** on GitHub with:
   - Clear title describing the change
   - Detailed description of what changed and why
   - Reference any related issues
   - Screenshots if applicable

### Commit Message Format
Follow conventional commits:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Adding or updating tests
- `refactor:` Code refactoring
- `chore:` Maintenance tasks

## Code Review

- Be responsive to feedback
- Make requested changes promptly
- Keep discussions professional and constructive
- Update your PR based on review comments

## Reporting Issues

### Bug Reports
Include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (AWS region, versions, etc.)
- Relevant logs or error messages

### Feature Requests
Include:
- Clear description of the feature
- Use case and benefits
- Proposed implementation (if any)

## Security Issues

**Do not open public issues for security vulnerabilities.**

Report security issues privately via GitHub Security Advisory or email the maintainers.

## Questions?

- Check existing issues and documentation first
- Open a discussion for general questions
- Be specific and provide context

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

Thank you for contributing! 🎉
