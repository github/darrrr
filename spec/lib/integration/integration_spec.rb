# frozen_string_literal: true

require_relative "../../spec_helper"

describe "Integration test", vcr: { cassette_name: "delegated_account_recovery/integration_test" } do
  it "serves up the config" do
    visit "/.well-known/delegated-account-recovery/configuration"
    response = JSON.parse(body)
    expect(response).to include(Darrrr::AccountProvider.this.to_h)
    expect(response).to include(Darrrr::RecoveryProvider.this.to_h)
  end

  it "can store and recover a token" do
    visit "/account-provider"
    secret = find_field(:phrase).value
    page.click_on("connect to http://localhost:9292")
    page.click_on("Setup recovery")
    page.click_on("Recover now?")
    page.click_on("Recover token")

    assert_text("Recovered data: #{secret}")
  end
end
