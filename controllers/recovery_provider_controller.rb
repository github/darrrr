require_relative "../models/token"

class RecoveryProviderController < MainController
  post "/save-token" do
    response = { state: params[:state] }

    begin
      token = Base64.decode64(params[:token])
      account_provider = Darrrr::RecoveryToken.account_provider_issuer(token)
      token = Darrrr.this_recovery_provider.validate_recovery_token!(token)
      persisted_token = RecoveryToken.create({
        provider: account_provider.origin,
        token_id: token.token_id.to_hex,
        token_blob: params[:token]
      })
      response[:status] = "save-success"

      audit("token stored with recovery provider", token.token_id.to_hex)
      notify("we haz your token", account_provider)
    rescue Darrrr::RecoveryTokenError => e
      response[:status] = "save-failure"
    end

    redirect to("#{account_provider.save_token_return}?#{response.map{|key, value| "#{key}=#{value}"}.join("&")}")
  end

  route :get, :post, "/recover-account" do
    token = Base64.decode64(RecoveryToken.find_by_token_id(params[:token_id] || params[:id]).token_blob)

    account_provider = Darrrr::RecoveryToken.account_provider_issuer(token)
    countersigned_recovery_token = Darrrr.this_recovery_provider.countersign_token(token)

    audit("recovery initiated", Darrrr::RecoveryToken.parse(token).token_id.to_hex)
    notify("we've countersigned and sent a recovery token", account_provider)

    erb :recover_account_return_post, locals: {
      token: countersigned_recovery_token,
      recover_account_return_endpoint: account_provider.recover_account_return,
    }
  end
end
