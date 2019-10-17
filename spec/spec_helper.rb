require 'rspec/core'
require 'rspec/retry'
require 'hatchet'
require 'fileutils'

ENV['RACK_ENV'] = 'test'

DEFAULT_STACK = 'heroku-18'

RSpec.configure do |config|
  config.full_backtrace = true  # Print full backtraces on error
  config.verbose_retry  = true  # Show retry status in spec process
  config.default_retry_count = 2 if ENV['IS_RUNNING_ON_CI']
  config.color_mode = :on if ENV['IS_RUNNING_ON_CI'] # Enable color on CI

  # Use rspec-expectations library
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    # Use `expect` rather than `should` syntax
    expectations.syntax = :expect
  end

  # Don't use any mocking framework
  config.mock_with :nothing

  # Format test cases with test descriptions
  config.default_formatter = 'doc'

  # Limits the available syntax to the non-monkey patched syntax. That is,
  # the old `should` syntax is replaced with the new `expect` syntax which
  # fixes some commom issues such as delegating methods and makes the test
  # more straightforward and stable. For more information see
  # http://rspec.info/blog/2012/06/rspecs-new-expectation-syntax
  config.disable_monkey_patching!

  # Run all tests on CI systems by default, but only run focused
  # tests if certain groups, contexts or examples are tagged with
  # `focused: true`. This is useful for debugging single tests.
  config.filter_run_when_matching :focus unless ENV['IS_RUNNING_ON_CI']

  # Fail if no examples are found
  config.fail_if_no_examples = true

  # Profile the 10 slowest examples and example groups and print them
  # out at the end. This helps to surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3). It causes shared context metadata to be
  # inherited by the metadata hash of host groups and examples, rather than
  # triggering implicit auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups
end

def init_app(app, stack = DEFAULT_STACK)
  app.setup!
  app.update_stack(ENV['HEROKU_TEST_STACK'] || stack)
end

def successful_body(app, options = {})
  wait_for_dyno_startup(app)
  retry_limit = options[:retry_limit] || 50
  path = options[:path] ? "/#{options[:path]}" : ""
  Excon.get("https://#{app.name}.herokuapp.com#{path}",
            :idempotent => true,
            :expects => 200,
            :retry_limit => retry_limit).body
end

def set_wildfly_version(app_dir, version)
  Dir.chdir(app_dir) do
    File.open('system.properties', 'a') do |file|
      file.puts "wildfly.version=#{version}"
    end
    `git add system.properties`
    `git commit -m "Setting WildFly version #{version}"`
  end
end

def clear_system_properties(app_dir)
  Dir.chdir(app_dir) do
    File.delete('system.properties') if File.file?('system.properties')
  end
end

def set_java_version(app_dir, version)
  Dir.chdir(app_dir) do
    File.open('system.properties', 'a') do |file|
      file.puts "java.runtime.version=#{version}"
    end
    `git add system.properties`
    `git commit -m "Setting Java version #{version}"`
  end
end

def dyno_status(app, ps_name = "web")
  app
    .api_rate_limit.call
    .dyno
    .list(app.name)
    .detect { |dyno| dyno["type"] == ps_name }
end

def wait_for_dyno_startup(app, ps_name = "web", sleep_val = 1)
  while ["starting", "restarting"].include?(dyno_status(app, ps_name)["state"])
    sleep sleep_val
  end
  dyno_status(app, ps_name)
end
