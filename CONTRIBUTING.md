# Contributing to Nucleoc

Thank you for your interest in contributing to Nucleoc! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

### Prerequisites
- Crystal 1.18.2 or later
- Git

### Development Setup
1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/nucleoc.git`
3. Install dependencies: `shards install`
4. Run tests: `crystal spec`

## Development Workflow

### 1. Branch Naming
- Feature: `feature/description`
- Bug fix: `fix/description`
- Documentation: `docs/description`
- Refactor: `refactor/description`

### 2. Code Style
- Follow Crystal's official style guide
- Run `crystal tool format` before committing
- Run `ameba` to check for linting issues
- Write tests for new functionality

### 3. Commit Messages
Use conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### 4. Pull Requests
1. Create a descriptive PR title
2. Link related issues
3. Provide clear description of changes
4. Ensure all tests pass
5. Update documentation if needed

## Testing

### Running Tests
```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/nucleoc_spec.cr

# Run with verbose output
crystal spec --verbose
```

### Test Guidelines
- Write unit tests for new functionality
- Include edge cases
- Test both success and failure scenarios
- Mock external dependencies when appropriate

## Code Quality

### Linting
```bash
# Run Ameba linter
ameba

# Run with auto-fix
ameba --fix
```

### Formatting
```bash
# Check formatting
crystal tool format --check src/ spec/

# Apply formatting
crystal tool format src/ spec/
```

## Documentation

### API Documentation
- Document public methods and classes
- Use Crystal's documentation format
- Include examples when appropriate

### README Updates
- Update README.md for new features
- Add usage examples
- Update installation instructions if needed

## Release Process

### Versioning
We follow [Semantic Versioning](https://semver.org/):
- MAJOR: Incompatible API changes
- MINOR: Backward-compatible functionality
- PATCH: Backward-compatible bug fixes

### Changelog
- Update CHANGELOG.md for all changes
- Follow Keep a Changelog format
- Include breaking changes section

## Getting Help

- Check existing issues and PRs
- Ask questions in discussions
- Join the Crystal community

## Recognition

All contributors will be acknowledged in the README.md file.

Thank you for contributing to Nucleoc!