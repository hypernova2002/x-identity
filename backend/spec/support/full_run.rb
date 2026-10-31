# Whether this run is the whole suite, with no files left out and no filters, as pre-commit and CI
# run it. Coverage thresholds and the route check only mean something then.
module FullRun
  def self.active?
    configuration = RSpec.configuration
    configuration.files_to_run.size == Rails.root.glob("spec/**/*_spec.rb").size && configuration.filter_manager.inclusions.empty?
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    next unless FullRun.active?

    SimpleCov.configure do
      coverage :line, minimum: 97.8
      coverage :branch, minimum: 79.7
    end
  end
end
