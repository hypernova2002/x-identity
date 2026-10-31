# Every route must be reached by at least one request spec. Checked when the whole suite runs. A
# route counts as reached when a request at its path ran its action, whatever the verb, so a
# resource's PUT alias is covered by its PATCH.
module RouteCoverage
  REACHED = Set.new

  def self.key(controller, action, path)
    "#{controller}##{action} #{path.delete_suffix('(.:format)')}"
  end

  # @return [Array<String>] each route no request reached, as "VERB /path"
  def self.unreached
    Rails.application.routes.routes.filter_map do |route|
      controller, action = route.defaults.values_at(:controller, :action)
      next if controller.nil? || route.verb.empty?

      path = route.path.spec.to_s
      "#{route.verb} #{path.delete_suffix('(.:format)')}" unless REACHED.include?(key(controller, action, path))
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
      pattern = payload[:request].route_uri_pattern
      RouteCoverage::REACHED << RouteCoverage.key(payload[:params]["controller"], payload[:action], pattern) if pattern
    end
  end

  config.after(:suite) do
    next unless FullRun.active?

    unreached = RouteCoverage.unreached
    raise "Routes no request spec reaches:\n  #{unreached.join("\n  ")}" if unreached.any?
  end
end
