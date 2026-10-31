require "rails_helper"

# Each project endpoint behaves the same on a custom domain as under /v1, where its request specs
# cover it; this checks that every custom-domain route reaches its own action for the domain's project.
RSpec.describe "Routing on a custom domain", type: :request do
  let(:project) { create(:project) }

  before do
    project.domains.create!(hostname: "login.acme.com", status: "verified", verified_at: Time.current)
    host! "login.acme.com"
    https!
  end

  custom_domain_routes = Rails.application.routes.routes.select do |route|
    route.app.respond_to?(:constraints) && route.app.constraints.include?(CustomDomainConstraint) && route.defaults[:controller]
  end

  custom_domain_routes.each do |route|
    verb = route.verb.split("|").first
    path = route.path.spec.to_s.delete_suffix("(.:format)").gsub(/:\w+/, "unknown")
    controller, action = route.defaults.values_at(:controller, :action)

    it "#{verb} #{path} reaches #{controller}##{action}" do
      reached = []
      subscription = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
        reached << [ payload[:params]["controller"], payload[:action], payload[:request].path_parameters ]
      end

      process(verb.downcase.to_sym, path, as: (:json unless verb == "GET"))

      expect(reached.map { |reached_controller, reached_action, _| "#{reached_controller}##{reached_action}" }).to eq([ "#{controller}##{action}" ])
      expect(response.status).to be < 500
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
  end
end
