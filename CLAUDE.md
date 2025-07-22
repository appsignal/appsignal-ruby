# AppSignal Ruby Gem

This is the Ruby gem for AppSignal, an application performance monitoring (APM) service.

## Project Structure

Directories:

- `bin/` - Directory with executables that can be called once the Ruby gem is installed
- `lib/` - Main library code
  - `appsignal.rb` - Main module of the Ruby gem
  - `appsignal/` - Library code
    - `capistrano.rb` - Capistrano integration
    - `check_in/` - Check-in functionality
    - `cli/` - Command Line Interface modules
    - `config.rb` - Configuration management
    - `event_formatter/` - Event formatting for different frameworks
    - `extension.rb` - C extension module, extended by the C extension
    - `extension/` - C extension modules in the Ruby gem
    - `hooks/` - Ruby gem hooks and may contain integration code
    - `integrations/` - Ruby gem integrations, loaded by the hooks
    - `loaders/` - Ruby gem loaders, integrations manually loaded by applications
    - `logger.rb` - Logger functionality
    - `probes/` - Minutely probes
    - `rack/` - Rack middleware for various Ruby gems
    - `span.rb` - Tracing span API (private API)
    - `transaction.rb` - Tracing transaction API
    - `utils/` - Utility modules
    - `puma/plugin/appsignal.rb` - AppSignal Puma plugin
    - `sequel/extensions/appsignal_integration.rb` - AppSignal Sequel plugin placeholder
- `ext/` - Native C extension
  - `appsignal_extension.c` - Main C extension
  - `base.rb` - Extension installation script helpers shared between the MRI Ruby and JRuby installers
  - `extconf.rb` - Extension installation script for MRI Ruby
  - `Rakefile` - Extension installation script for JRuby
  - `agent.rb` - Agent bootstrapping
- `spec/` - RSpec test suite
  - `lib/` - Unit tests
  - `integration/` - Integration tests
  - `support/` - Test helpers, matchers, shared examples, stubs and fixtures
- `gemfiles/` - Gemfile variations used for testing
- `resources/` - Configuration templates
- `script/` - Development scripts

Files:

- `Gemfile`: Additional development dependencies
- `Rakefile`: Build and development tasks
- `appsignal.gemspec`: Gem specification
- `build_matrix.yml`: Build matrix configuration
- `mono.yml`: [Mono](https://github.com/appsignal/mono/) release configuration

## Key Components

### Core Library Files (`lib/`)

- `appsignal.rb`: Main Ruby gem module with the public API
- `appsignal/helpers/instrumentation.rb`: Tracing instrumentation helpers
- `appsignal/helpers/metrics.rb`: Metrics helpers
- `appsignal/config.rb`: Configuration management and validation
- `appsignal/transaction.rb`: Transaction API
- `appsignal/extension.rb`: Interface to native C extension
- `appsignal/hooks/`: Framework-specific instrumentation hooks
- `appsignal/integrations/`: Framework integrations (Rails, Sidekiq, etc.)
- `appsignal/rack/`: Rack middleware for web frameworks

### Native Extension (`ext/`)

- `appsignal_extension.c`: C extension for performance-critical operations
- `extconf.rb`: Extension build configuration
- `agent.rb`: Agent initialization and management

### Framework Support

The gem supports numerous web frameworks like:

- Grape
- Hanami
- Padrino
- Rails, including:
    - Action Cable
    - Active Support Notifications
    - Active Job, and all adapters
    - Action Mailer
- Sinatra
- Webmachine

Background job libraries like:

- DelayedJob
- Resque
- Shoryuken
- Sidekiq

Database drivers like:

- DataMapper
- MongoDB
- Redis and redis-client
- Sequel

And gems like:

- Capistrano
- Excon
- Net::HTTP
- Ownership
- Passenger
- Puma
- Rake
- Unicorn

## Development Commands

### Setup

```bash
# Install dependencies
bundle install

# Install the extension
rake extension:install
```

### Testing

```bash
# Run the test suite
bundle exec rspec

# Run tests for specific framework
BUNDLE_GEMFILE=gemfiles/<gemfile>.gemfile bundle exec rspec
```

### Extension development

```bash
# Install or reinstall the extension
rake extension:install

# For JRuby
cd ext && rake
```

## File organization

### Configuration files

### Testing structure

- `spec/lib/`: Unit tests mirroring `lib/` structure
- `spec/integration/`: Integration and end-to-end tests
- `spec/support/`: Test helpers, mocks, and fixtures

### Continuous integration

- `build_matrix.yml`: CI build matrix configuration
- `.github/workflows/ci.yml`: GitHub Actions workflow (auto-generated)

Update the generated `.github/workflows/ci.yml` file by running the following command:

```bash
rake build_matrix:github:generate
```

The script to generate the `.github/workflows/ci.yml` file is part of the `Rakefile`.

## Important Notes

- The gem includes both Ruby and Java (JRuby) versions.
- Native C extension provides performance-critical functionality.
- Extensive test matrix covers multiple Ruby versions and frameworks.
- Uses mono for automated releases and changelog management.

## Documentation

The Ruby gem is documented using YARD and is paired with documentation on the AppSignal documentation website at: https://docs.appsignal.com/ruby.html
