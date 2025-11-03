# Contributing to Webhookable

First off, thank you for considering contributing to Webhookable! It's people like you that make Webhookable such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples to demonstrate the steps**
- **Describe the behavior you observed and what behavior you expected**
- **Include Ruby/Rails versions and Webhookable version**
- **Include any relevant logs or error messages**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear and descriptive title**
- **Provide a detailed description of the suggested enhancement**
- **Explain why this enhancement would be useful**
- **List any similar features in other gems if applicable**

### Pull Requests

- Fill in the required template
- Follow the Ruby style guide (enforced by Rubocop)
- Include tests for all changes
- Update documentation as needed
- Ensure all tests pass
- Keep pull requests focused on a single feature or fix

## Development Process

### Setting Up Your Development Environment

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/webhookable.git
   cd webhookable
   ```

3. Install dependencies:
   ```bash
   bundle install
   ```

4. Create a branch for your changes:
   ```bash
   git checkout -b feature/my-new-feature
   ```

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/webhookable/signature_spec.rb

# Run with coverage
bundle exec rspec --format documentation
```

### Code Style

We use Rubocop to enforce code style:

```bash
# Check for style violations
bundle exec rubocop

# Auto-fix violations where possible
bundle exec rubocop -a
```

### Writing Tests

- Write tests for all new features and bug fixes
- Use descriptive test names
- Follow the existing test structure
- Aim for 100% code coverage
- Use factories instead of fixtures

Example test structure:

```ruby
RSpec.describe Webhookable::MyFeature do
  describe "#my_method" do
    context "when condition is true" do
      it "does something expected" do
        # Arrange
        subject = create(:my_model)

        # Act
        result = subject.my_method

        # Assert
        expect(result).to eq(expected_value)
      end
    end

    context "when condition is false" do
      it "handles the alternative case" do
        # ...
      end
    end
  end
end
```

### Documentation

- Update README.md if you change functionality
- Add inline documentation for complex methods
- Update CHANGELOG.md following [Keep a Changelog](https://keepachangelog.com/)
- Include examples in documentation

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

Example:

```
Add webhook delivery retry limit configuration

- Add max_retry_attempts configuration option
- Update delivery logic to respect the limit
- Add tests for new configuration
- Update README with configuration example

Fixes #123
```

## Release Process

Maintainers will handle releases:

1. Update version in `lib/webhookable/version.rb`
2. Update CHANGELOG.md with release date
3. Commit changes: `git commit -am "Release v0.X.X"`
4. Tag the release: `git tag v0.X.X`
5. Push changes: `git push && git push --tags`
6. Build and publish gem: `gem build webhookable.gemspec && gem push webhookable-0.X.X.gem`

## Getting Help

- Check the [README](README.md) for documentation
- Look through existing [issues](https://github.com/magnusfremont/webhookable/issues)
- Ask questions in new issues with the "question" label

## Recognition

Contributors will be recognized in:
- The project README
- Release notes for their contributions
- GitHub's contributor graph

Thank you for contributing to Webhookable!
