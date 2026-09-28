# Contributing to Stoplight

Thank you for your interest in contributing to Stoplight! This guide will help you understand our codebase architecture 
and how to make effective contributions. If you're lost in the code, please read [architecture.md] 

## Development Setup

### Prerequisites

- Ruby version as defined at `stoplight.gemspec`
- Bundler

### Getting Started

```bash
# Clone the repository
git clone https://github.com/bolshakov/stoplight.git
cd stoplight

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run cucumber features with Redis data store  
STOPLIGHT_DATA_STORE=Redis bundle exec cucumber
 
 # Run cucumber features with Memory data store  
STOPLIGHT_DATA_STORE=Memory bundle exec cucumber

# Run linter
bundle exec standardrb

# Auto-fix linting issues
bundle exec standardrb --fix
```

## Making Changes

### Before You Start

1. **Check existing issues** - Look for related discussions
2. **Open an issue** - Discuss major changes before coding
3. **Create a branch** off `main` - Use descriptive names: `feature/add-retry-strategy`, `fix/memory-leak`

## Branches and Releases

`main` is the only long-lived branch. Every pull request targets it, and every release is a tag on it.

### Releasing

1. Open a pull request against `main` that bumps `Stoplight::VERSION` in `lib/stoplight/version.rb`, and merge it.
2. Publish a GitHub Release with a new tag, such as `v6.1.0`, targeting `main`. Publishing creates the tag, saving a
   draft does not. The form tags the target as it is at that moment, so if `main` has moved past the version bump,
   target the bump commit instead. Mark prereleases such as `v6.1.0.rc1` as pre-releases.
3. The new tag runs the Release workflow. It fails unless the tag matches the gem version, then publishes the gem and
   the `stoplight-admin` Docker image. Prerelease versions do not move the `latest` image.

Pushing the tag with git (`git tag v6.1.0 && git push origin v6.1.0`) works too. Then publish the GitHub Release for
the existing tag - that page is the change log.

### Hotfixes

A fix for an already released version starts from that version's tag, not from `main`, because `main` may already
carry unreleased changes:

```bash
git switch -c hotfix/v6.0.1 v6.0.0
```

Commit the fix and the version bump there, push the branch, and release it as above, targeting the hotfix branch
instead of `main`. If the bug also exists on `main`, cherry-pick the fix onto a branch off `main` and open a pull
request as usual. Delete the hotfix branch once the tag exists - the tag keeps the commits.

GitHub runs the Release workflow from the tagged commit, so a hotfix cut from a tag older than v6.0.0 carries the old
workflow, which does not react to tags. Bring the current one onto the hotfix branch before tagging:

```bash
git checkout main -- .github/workflows/release.yml
```

## Testing Guidelines

### Test Organization

- **Unit tests** (`spec/unit/`) - Fast, isolated, no I/O
- **Integration tests** (`spec/integration/`) - End-to-end scenarios
- **Feature tests** (`features/`) - User-facing behavior

### Unit Test Principles

Use test doubles for testing with abstract dependencies:

```ruby
RSpec.describe Stoplight::Domain::Light do
  let(:state_store) { instance_double(NullStateStore) }
  let(:notifier) { instance_double(NullNotifier) }
  
  # Test in isolation
  it "transitions to red after threshold" do
    allow(state_store).to receive(:transition_to_color)
    # ... test logic
  end
end
```

Use real dependencies when testing infrastructure

```ruby
RSpec.describe Stoplight::Infrastructure::Redis::Storage::State do
  let(:state_store) { described_class.new(clock:, redis:, key_space:, cool_off_time:) }
  let(:redis) { Redis.new(url: connection_string) } # connects to the real database
  
  it "transitions to red" do
    state_store.transition_to_color(Stoplight::Color::RED)
    # ... test logic
  end
end
```

### Integration Test Principles

All user-facing functionality (described in the README file) should be covered with feature tests. In rare cases when 
it's tricky to use gherkin language for testing, you can opt out to using integration tests:

```ruby
RSpec.describe "Concurrency testing" do
  # Use real implementations
  let(:state_store) { Stoplight::Infrastructure::Redis::Storage::State.new(clock:, redis:, key_space:, cool_off_time:) }
  
  it "persists state across instances" do
    # Test actual integration
  end
end
```

## Getting Help

- **Questions?** Open a discussion on GitHub
- **Found a bug?** Open an issue with reproduction steps
- **Need guidance?** Tag maintainers in your PR

---

Thank you for contributing to Stoplight! Your efforts help make circuit breakers more reliable for everyone.

[architecture.md]: https://github.com/bolshakov/stoplight/blob/main/docs/architecture.md
