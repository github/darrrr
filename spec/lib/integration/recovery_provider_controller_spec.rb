require_relative "../../spec_helper"

describe "AccountProviderController", vcr: { cassette_name: "delegated_account_recovery/integration_test" } do
  include Rack::Test::Methods

  def app
    Rack::Builder.parse_file("config.ru").first
  end

  it "saves a token" do
    token = example_account_provider.generate_recovery_token(data: "foo", audience: Darrrr::RecoveryProvider.this)
    sealed_token = example_account_provider.seal(token)
    post "/recovery-provider/save-token", token: sealed_token
    expect(last_response.header["location"]).to match("save-success")
  end

  it "rejects a bad token" do
    token = example_account_provider.generate_recovery_token(data: "foo", audience: Darrrr::RecoveryProvider.this)
    sealed_token = example_account_provider.seal(token)
    sealed_token = sealed_token[0..-5]
    post "/recovery-provider/save-token", token: sealed_token
    expect(last_response.header["location"]).to match("save-failure")
  end
end
