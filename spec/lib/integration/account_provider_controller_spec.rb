require_relative "../../spec_helper"

describe "AccountProviderController", vcr: { cassette_name: "delegated_account_recovery/integration_test" } do
  include Rack::Test::Methods

  def app
    Rack::Builder.parse_file("config.ru").first
  end

  it "creates a token" do
    post "/account-provider/create", recovery_provider: example_recovery_provider.origin, phrase: "foo"
    expect(last_response.status).to eq(200)
  end
end
