# frozen_string_literal: true

class AccountProviderController < MainController
  # 1 select recovery provider
  get "/" do
    erb :index
  end

  post "/create" do
    recovery_provider = Darrrr.recovery_provider(params["recovery_provider"])
    token, sealed_token = Darrrr.this_account_provider.generate_recovery_token(data: params["phrase"], audience: recovery_provider)

    ReferenceToken.create({
      provider: recovery_provider.origin,
      token_id: token.token_id.to_hex,
    })

    audit("token created", token.token_id.to_hex)

    session[:state] = token.state_url
    erb :recovery_post, locals: {
      state: token.state_url,
      endpoint: recovery_provider.save_token,
      payload: sealed_token,
      token: token, # just for debugging
    }
  end

  get "/save-token-return" do
    if Sinatra::Application.environment != :test && !Rack::Utils.secure_compare(params[:state], session[:state])
      raise "CSRF attack"
    end

    # notify the user
    # add audit log entry
    token_id = Addressable::URI.parse(params[:state]).query_values["id"]
    token = ReferenceToken.find_by_token_id!(token_id)
    recovery_provider = Darrrr.recovery_provider(token.provider)

    case params[:status]
    when "save-success"
      token.update_attribute(:confirmed_at, Time.now)
      notify("token saved", recovery_provider)
      audit("token confirmed", token_id)
      erb :save_token_success, locals: { recover_uri: params[:state] }
    when "save-failure"
      notify("token not saved", recovery_provider)
      audit("token unsuccessfully saved", token_id)
      erb :save_token_failure
    end
  end

  route :get, :post, "/recover-account-return" do
    unless request.content_type == "application/x-www-form-urlencoded"
      halt 400, "Invalid request format"
      return
    end
    countersigned_token = params[:token]
    recovery_provider = Darrrr::RecoveryToken.recovery_provider_issuer(Base64.strict_decode64(countersigned_token))
    begin
      parsed_token = Darrrr.this_account_provider.validate_countersigned_recovery_token!(countersigned_token)
    rescue Darrrr::CountersignedTokenError => e
      notify("token recovery unsucessful", recovery_provider)
      halt 400, e.message
    end

    persisted_token = ReferenceToken.find_by_token_id!(parsed_token.token_id.to_hex)
    persisted_token.update_attribute(:recovered_at, Time.now)
    notify("token recovered", recovery_provider)
    audit("token recovered", parsed_token.token_id)

    erb :recovered, locals: { decrypted_data: parsed_token.decode }
  end
end
