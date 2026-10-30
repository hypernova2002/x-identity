require "rails_helper"

RSpec.describe "The API reference" do
  def route_signature(verb, path)
    "#{verb} #{path.gsub(/\{\w+\}|:\w+/, '{}')}"
  end

  it "documents every route" do
    documented = YAML.load_file(Rails.root.join("openapi/public_api.yaml"))["paths"].flat_map do |path, operations|
      (operations.keys & %w[get post put patch delete]).map { |verb| route_signature(verb.upcase, path) }
    end

    # Custom domains serve the same routes without the /v1 prefix. Hosted login's interactions serve
    # only the hosted pages, so they're left out for apps not to depend on.
    routes = Rails.application.routes.routes.flat_map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      next [] unless path.start_with?("/v1/") && !path.include?("/oauth2/interactions/")

      route.verb.split("|").map { |verb| route_signature(verb, path) }
    end.uniq
    put_aliases = routes.select { |route| route.start_with?("PATCH ") }.map { |route| route.sub("PATCH", "PUT") }

    expect(routes - put_aliases - documented).to eq([])
  end
end
