[![Code Climate](https://codeclimate.com/github/github/darrrr/badges/gpa.svg)](https://codeclimate.com/github/github/darrrr)
![Build + Test](https://github.com/github/darrrr/workflows/Build%20+%20Test/badge.svg?branch=master)

The Delegated Account Recovery Rigid Reusable Ruby (aka D.a.r.r.r.r. or "Darrrr") library is meant to be used as the fully-complete plumbing in your Rack application when implementing the [Delegated Account Recovery specification](https://github.com/facebook/DelegatedRecoverySpecification). This library is currently used for the implementation at [GitHub](https://githubengineering.com/recover-accounts-elsewhere/).

Along with a fully featured library, a proof of concept application is provided in this repo.

![](/logos/dar-logo-transparent-small.png)

## Configuration

An account provider (e.g. GitHub) is someone who stores a token with someone else (a recovery provider e.g. Facebook) in order to grant access to an account.

In `config/initializers` or any location that is run during application setup, add a file. **NOTE:** `proc`s are valid values for `countersign_pubkeys_secp256r1` and `tokensign_pubkeys_secp256r1`

```ruby
Darrrr.authority = "http://localhost:9292"
Darrrr.privacy_policy = "#{Darrrr.authority}/articles/github-privacy-statement/"
Darrrr.icon_152px = "#{Darrrr.authority}/icon.png"

# See script/setup for instructions on how to generate keys
Darrrr::AccountProvider.configure do |config|
  config.signing_private_key = ENV["ACCOUNT_PROVIDER_PRIVATE_KEY"]
  config.symmetric_key = ENV["TOKEN_DATA_AES_KEY"]
  config.tokensign_pubkeys_secp256r1 = [ENV["ACCOUNT_PROVIDER_PUBLIC_KEY"]] || lambda { |provider, context| "you wouldn't do this in real life but procs are supported for this value" }
  config.save_token_return = "#{Darrrr.authority}/account-provider/save-token-return"
  config.recover_account_return = "#{Darrrr.authority}/account-provider/recover-account-return"
end

Darrrr::RecoveryProvider.configure do |config|
  config.signing_private_key = ENV["RECOVERY_PROVIDER_PRIVATE_KEY"]
  config.countersign_pubkeys_secp256r1 = [ENV["RECOVERY_PROVIDER_PUBLIC_KEY"]] || lambda { |provider, context| "you wouldn't do this in real life but procs are supported for this value" }
  config.token_max_size = 8192
  config.save_token = "#{Darrrr.authority}/recovery-provider/save-token"
  config.recover_account = "#{Darrrr.authority}/recovery-provider/recover-account"
end
```

The delegated recovery spec depends on publicly available endpoints serving standard configs. These responses can be cached but are not by default. To configure your cache store, provide the reference:

```ruby
Darrrr.cache = Dalli::Client.new('localhost:11211', options)
```

The spec disallows `http` URIs for basic security, but sometimes we don't have this setup locally.

```ruby
Darrrr.allow_unsafe_urls = true
```

## Provider registration

In order to allow a site to act as a provider, it must be "registered" on boot to prevent unauthorized providers from managing tokens.

```ruby
# Only configure this if you are acting as a recovery provider
Darrrr.register_account_provider("https://github.com")

# Only configure this if you are acting as an account provider
Darrrr.register_recovery_provider("https://www.facebook.com")
```

## Custom crypto

Create a module that responds to `Module.sign`, `Module.verify`, `Module.decrypt`, and `Module.encrypt`. You can use the template below. I recommend leaving the `#verify` method as is unless you have a compelling reason to override it.

### Global config

Set `Darrrr.this_account_provider.custom_encryptor = MyCustomEncryptor`
Set `Darrrr.this_recovery_provider.custom_encryptor = MyCustomEncryptor`

### On-demand

```ruby
Darrrr.with_encryptor(MyCustomEncryptor) do
  # perform DAR actions using MyCustomEncryptor as the crypto provider
  recovery_token, sealed_token = Darrrr.this_account_provider.generate_recovery_token(data: "foo", audience: recovery_provider, context: { user: current_user })
end
```

```ruby
module MyCustomEncryptor
  class << self
    # Encrypts the data in an opaque way
    #
    # data: the secret to be encrypted
    #
    # returns a byte array representation of the data
    def encrypt(data)

    end

    # Decrypts the data
    #
    # ciphertext: the byte array to be decrypted
    #
    # returns a string
    def decrypt(ciphertext)

    end

    # payload: binary serialized recovery token (to_binary_s).
    #
    # key: the private EC key used to sign the token
    #
    # returns signature in ASN.1 DER r + s sequence
    def sign(payload, key)

    end

    # payload: token in binary form
    # signature: signature of the binary token
    # key: the EC public key used to verify the signature
    #
    # returns true if signature validates the payload
    def verify(payload, signature, key)
      # typically, the default verify function should be used to ensure compatibility
      Darrrr::DefaultEncryptor.verify(payload, signature, key)
    end
  end
end
```

## Example implementation

I strongly suggest you read the specification, specifically section 3.1 (save-token) and 3.5 (recover account) as they contain the most dangerous operations.

**NOTE:** this is NOT meant to be a complete implementation, it is just the starting point. Crucial aspects such as authentication, audit logging, out of band notifications, and account provider persistence are not implemented.

* [Account Provider](controllers/account_provider_controller.rb) (save-token-return, recover-account-return)
* [Recovery Provider](controllers/recovery_provider_controller.rb) (save-token, recover-account)
* [Configuration endpoint](controllers/well_known_config_controller.rb) (`/.well-known/delegated-account-recovery/configuration`)

Specifically, the gem exposes the following APIs for manipulating tokens.
* Account Provider
  * [Generating](https://github.com/github/darrrr/blob/faafda5b1773e077c9c10b55b46216f97d13cd3b/lib/github/delegated_account_recovery/account_provider.rb#L49) a token
  * Signing ([`#seal`](https://github.com/github/darrrr/blob/faafda5b1773e077c9c10b55b46216f97d13cd3b/lib/github/delegated_account_recovery/crypto_helper.rb#L13)) a token
  * Verifying ([`#unseal`](https://github.com/github/darrrr/blob/faafda5b1773e077c9c10b55b46216f97d13cd3b/lib/github/delegated_account_recovery/crypto_helper.rb#L30)) a countersigned token
* Recovery Provider
  * Verifying ([`#unseal`](https://github.com/github/darrrr/blob/faafda5b1773e077c9c10b55b46216f97d13cd3b/lib/github/delegated_account_recovery/crypto_helper.rb#L30)) a token
  * [Countersigning](https://github.com/github/darrrr/blob/faafda5b1773e077c9c10b55b46216f97d13cd3b/lib/github/delegated_account_recovery/recovery_provider.rb#L60) a token

### Development

Local development assumes a Mac OS environment with [homebrew](https://brew.sh/) available. Postgres and phantom JS will be installed.

Run `./script/bootstrap` then run `./script/server`

* Visit `http://localhost:9292/account-provider`
  * (Optionally) Record the random number for verification
  * Click "connect to http://localhost:9292"
* You'll see some debug information on the page.
  * Click "setup recovery".
* If recovery setup was successful, click "Recovery Setup Successful"
* Click the "recover now?" link
* You'll see an intermediate page, where more debug information is presented. Click "recover token"
* You should be sent back to your host
  * And see something like `Recovered data: <the secret from step 1>`

### Tests

Run `./script/test` to run all tests.

## Deploying to heroku

Use `heroku config:set` to set the environment variables listed in [script/setup](/script/setup). Additionally, run:

```
heroku config:set HOST_URL=$(heroku info -s | grep web_url | cut -d= -f2)
```

Push your app to heroku:

```
git push heroku <branch-name>:master
```

Migrate the database:

```
heroku run rake db:migrate
```

Use the app!

```
heroku restart
heroku open
```

## Roadmap

* Add support for `token-status` endpoints as defined by the spec
* Add async API as defined by the spec
* Implement token binding as part of the async API

## Don't want to run `./script` entries?

See `script/setup` for the environment variables that need to be set.

## Contributions

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

`darrrr` is licensed under the [MIT license](LICENSE.md).

The MIT license grant is not for GitHub's trademarks, which include the logo designs. GitHub reserves all trademark and copyright rights in and to all GitHub trademarks. GitHub's logos include, for instance, the stylized designs that include "logo" in the file title in the following folder:  [logos](/logos).

GitHub® and its stylized versions and the Invertocat mark are GitHub's Trademarks or registered Trademarks. When using GitHub's logos, be sure to follow the GitHub [logo guidelines](https://github.com/logos).
