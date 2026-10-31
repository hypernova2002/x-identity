require "rails_helper"

RSpec.describe SamlApp do
  let(:app) { build(:saml_app) }

  it "needs a web URL for logout, when given" do
    expect(error_codes(app.tap { |saml_app| saml_app.slo_url = "javascript:alert(1)" }, :slo_url)).to eq([ :not_web_url ])
  end

  it "needs a readable certificate, which signed requests depend on" do
    app.sp_certificate = "not a certificate"
    expect(error_codes(app, :sp_certificate)).to eq([ :invalid_certificate ])
    expect(app.certificate).to be_nil

    app.assign_attributes(sp_certificate: nil, require_signed_requests: true)
    expect(error_codes(app, :require_signed_requests)).to eq([ :needs_sp_certificate ])
  end

  it "takes attribute mappings with unique names and known sources" do
    [
      "email", [ "email" ], [ { "name" => "email" } ], [ { "name" => "", "source" => "email" } ], [ { "name" => "x", "source" => "password" } ],
      [ { "name" => "x", "source" => "email" }, { "name" => "x", "source" => "uid" } ]
    ].each do |mappings|
      expect(error_codes(build(:saml_app, attribute_mappings: mappings), :attribute_mappings)).to eq([ :invalid_attribute_mappings ]), mappings.to_s
    end
    expect(build(:saml_app, attribute_mappings: [ { "name" => "plan", "source" => "custom:plan" } ])).to be_valid
  end
end
