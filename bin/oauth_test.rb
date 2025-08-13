#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "schwab"
require "json"

# Load environment variables
require "dotenv"
Dotenv.load

class OAuthTester
  attr_reader :client_id, :client_secret, :redirect_uri, :port

  def initialize
    @client_id = ENV["SCHWAB_CLIENT_ID"]
    @client_secret = ENV["SCHWAB_CLIENT_SECRET"]
    @redirect_uri = ENV["SCHWAB_REDIRECT_URI"] || "http://localhost:3000/callback"
    @port = URI.parse(@redirect_uri).port || 3000

    validate_credentials!
  end

  def run
    puts "\n🔐 Schwab OAuth Testing Tool"
    puts "=" * 50

    loop do
      show_menu
      choice = gets.chomp

      case choice
      when "1"
        generate_auth_url_only
      when "2"
        manual_code_exchange
      when "3"
        test_token_refresh
      when "4"
        show_current_config
      when "q", "Q"
        puts "\n👋 Goodbye!"
        break
      else
        puts "\n❌ Invalid choice. Please try again."
      end
    end
  end

  private

  def show_menu
    puts "\n📋 Main Menu:"
    puts "1. Generate authorization URL"
    puts "2. Exchange authorization code for tokens (paste redirect URL)"
    puts "3. Test token refresh (requires existing refresh token)"
    puts "4. Show current configuration"
    puts "Q. Quit"
    print("\nYour choice: ")
  end

  def validate_credentials!
    missing = []
    missing << "SCHWAB_CLIENT_ID" unless @client_id
    missing << "SCHWAB_CLIENT_SECRET" unless @client_secret

    unless missing.empty?
      puts "\n⚠️  Missing environment variables: #{missing.join(", ")}"
      puts "\nPlease set them in your .env file or environment:"
      puts "  export SCHWAB_CLIENT_ID='your_client_id'"
      puts "  export SCHWAB_CLIENT_SECRET='your_client_secret'"
      puts "  export SCHWAB_REDIRECT_URI='http://localhost:3000/callback' (optional)"
      exit(1)
    end
  end

  # Removed test_authorization_flow function as it's no longer needed with Postman callback

  def unused_test_authorization_flow
    puts "\n🚀 Starting OAuth Authorization Flow..."
    puts "Setting up local callback server on port #{port}..."

    # Generate state for CSRF protection
    state = SecureRandom.hex(16)

    # Generate authorization URL
    auth_url = Schwab::OAuth.authorization_url(
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
    )

    puts "\n📝 Authorization URL generated:"
    puts auth_url

    # Start local server to capture callback
    captured_code = nil
    captured_state = nil
    server_thread = Thread.new do
      # Determine if we need HTTPS
      uri = URI.parse(redirect_uri)

      server_config = {
        Port: port,
        Logger: WEBrick::Log.new("/dev/null"),
        AccessLog: [],
      }

      # Add SSL configuration if using HTTPS
      if uri.scheme == "https"
        require "webrick/https"
        require "openssl"

        # Generate self-signed certificate for testing
        key = OpenSSL::PKey::RSA.new(2048)
        cert = OpenSSL::X509::Certificate.new
        cert.version = 2
        cert.serial = 1
        cert.subject = OpenSSL::X509::Name.new([["CN", "localhost"]])
        cert.issuer = cert.subject
        cert.public_key = key.public_key
        cert.not_before = Time.now
        cert.not_after = Time.now + 365 * 24 * 60 * 60

        # Sign the certificate with the key
        cert.sign(key, OpenSSL::Digest.new("SHA256"))

        server_config.merge!(
          SSLEnable: true,
          SSLCertificate: cert,
          SSLPrivateKey: key,
          SSLVerifyClient: OpenSSL::SSL::VERIFY_NONE,
        )

        puts "\n🔒 Using HTTPS with self-signed certificate"
        puts "⚠️  Your browser will show a security warning - this is normal for testing"
        puts "Click 'Advanced' and 'Proceed to 127.0.0.1' (or similar) to continue"
      end

      server = WEBrick::HTTPServer.new(server_config)

      server.mount_proc("/callback") do |req, res|
        captured_code = req.query["code"]
        captured_state = req.query["state"]

        res.content_type = "text/html"
        res.body = <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>OAuth Callback Received</title>
            <style>
              body { font-family: Arial, sans-serif; margin: 40px; }
              .success { color: green; }
              .code { background: #f0f0f0; padding: 10px; margin: 10px 0; font-family: monospace; }
            </style>
          </head>
          <body>
            <h1 class="success">✅ Authorization Code Received!</h1>
            <p>You can close this window and return to the terminal.</p>
            <div class="code">
              <strong>Code:</strong> #{captured_code}<br>
              <strong>State:</strong> #{captured_state}
            </div>
          </body>
          </html>
        HTML

        server.shutdown
      end

      server.start
    end

    # Open browser
    puts "\n🌐 Opening browser..."
    puts "If the browser doesn't open automatically, please visit:"
    puts auth_url

    begin
      system("open '#{auth_url}' 2>/dev/null || xdg-open '#{auth_url}' 2>/dev/null || start '#{auth_url}' 2>/dev/null")
    rescue
      puts "\n⚠️  Could not open browser automatically."
    end

    puts "\n⏳ Waiting for callback... (login to Schwab and authorize the app)"
    server_thread.join

    # Verify state
    if captured_state != state
      puts "\n❌ State mismatch! Possible CSRF attack."
      puts "Expected: #{state}"
      puts "Received: #{captured_state}"
      return
    end

    puts "\n✅ Authorization code received!"
    puts "Code: #{captured_code}"

    # Exchange code for tokens
    print("\n🔄 Exchange authorization code for tokens? (y/n): ")
    if gets.chomp.downcase == "y"
      exchange_code_for_tokens(captured_code)
    end
  end

  def exchange_code_for_tokens(code)
    puts "\n🔄 Exchanging code for tokens..."

    begin
      result = Schwab::OAuth.get_token(
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
      )

      puts "\n✅ Token exchange successful!"
      puts "\n📋 Token Details:"
      puts "Access Token: #{result[:access_token][0..20]}..." if result[:access_token]
      puts "Refresh Token: #{result[:refresh_token][0..20]}..." if result[:refresh_token]
      puts "Expires In: #{result[:expires_in]} seconds" if result[:expires_in]
      puts "Expires At: #{result[:expires_at]}" if result[:expires_at]
      puts "Token Type: #{result[:token_type]}" if result[:token_type]

      # Save tokens to file for later use
      save_tokens_to_file(result)
    rescue => e
      puts "\n❌ Token exchange failed!"
      puts "Error: #{e.message}"
      puts "\nNote: Authorization codes expire quickly (usually within minutes)."
      puts "Try running the flow again with a fresh code."
    end
  end

  def test_token_refresh
    puts "\n🔄 Testing Token Refresh..."

    # Load saved tokens if available
    tokens = load_tokens_from_file

    if tokens.nil? || tokens[:refresh_token].nil?
      print("\n📝 Enter refresh token manually: ")
      refresh_token = gets.chomp

      if refresh_token.empty?
        puts "❌ No refresh token provided."
        return
      end
    else
      refresh_token = tokens[:refresh_token]
      puts "Using saved refresh token: #{refresh_token[0..20]}..."
    end

    begin
      result = Schwab::OAuth.refresh_token(
        refresh_token: refresh_token,
        client_id: client_id,
        client_secret: client_secret,
      )

      puts "\n✅ Token refresh successful!"
      puts "\n📋 New Token Details:"
      puts "Access Token: #{result[:access_token][0..20]}..." if result[:access_token]
      puts "Refresh Token: #{result[:refresh_token][0..20]}..." if result[:refresh_token]
      puts "Expires In: #{result[:expires_in]} seconds" if result[:expires_in]
      puts "Expires At: #{result[:expires_at]}" if result[:expires_at]

      # Save new tokens
      save_tokens_to_file(result)
    rescue => e
      puts "\n❌ Token refresh failed!"
      puts "Error: #{e.message}"
    end
  end

  def show_current_config
    puts "\n⚙️  Current Configuration:"
    puts "=" * 50
    puts "Client ID: #{client_id[0..10]}..." if client_id
    puts "Client Secret: #{client_secret[0..5]}..." if client_secret
    puts "Redirect URI: #{redirect_uri}"
    puts "API Base URL: #{Schwab.configuration.api_base_url}"
    puts "API Version: #{Schwab.configuration.api_version}"

    tokens = load_tokens_from_file
    if tokens
      puts "\n📁 Saved Tokens:"
      puts "Access Token: #{tokens[:access_token][0..20]}..." if tokens[:access_token]
      puts "Refresh Token: #{tokens[:refresh_token][0..20]}..." if tokens[:refresh_token]
      puts "Expires At: #{tokens[:expires_at]}" if tokens[:expires_at]
    else
      puts "\n📁 No saved tokens found."
    end
  end

  def generate_auth_url_only
    puts "\n🔗 Generating Authorization URL..."

    state = SecureRandom.hex(16)
    auth_url = Schwab::OAuth.authorization_url(
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
    )

    puts "\n📋 Authorization URL:"
    puts auth_url
    puts "\n📝 State (for CSRF validation): #{state}"
    puts "\n💡 Next Steps:"
    puts "1. Copy and open this URL in your browser"
    puts "2. Log in to Schwab and authorize the application"
    puts "3. You'll be redirected to #{redirect_uri}"
    puts "4. Copy the FULL URL from your browser's address bar"
    puts "   (Even if the page shows an error, the URL has what we need)"
    puts "5. Use option 2 to paste the URL and exchange for tokens"
    puts "\n⚠️  Authorization codes expire quickly (usually within 10 minutes)"
  end

  def manual_code_exchange
    puts "\n🔄 Manual Code Exchange"
    puts "=" * 50

    puts "\n📝 Steps:"
    puts "1. First use option 1 to generate an authorization URL"
    puts "2. Open that URL in your browser and authorize with Schwab"
    puts "3. You'll be redirected to your callback URL (browser may show error)"
    puts "4. Copy the entire URL from your browser's address bar"
    puts "   Example: #{redirect_uri}?code=ABC123&state=XYZ"

    print("\n📋 Paste the full redirect URL here: ")
    redirect_url = gets.chomp

    if redirect_url.empty?
      puts "❌ No URL provided."
      return
    end

    begin
      uri = URI.parse(redirect_url)
      params = URI.decode_www_form(uri.query || "").to_h

      code = params["code"]
      state = params["state"]

      if code.nil? || code.empty?
        puts "\n❌ No authorization code found in URL."
        puts "Make sure you copied the complete redirect URL including the ?code= parameter"
        return
      end

      puts "\n✅ Found authorization code: #{code[0..20]}..."
      puts "State: #{state}" if state

      print("\n🔄 Exchange this code for tokens? (y/n): ")
      if gets.chomp.downcase == "y"
        exchange_code_for_tokens(code)
      end
    rescue URI::InvalidURIError => e
      puts "\n❌ Invalid URL: #{e.message}"
    end
  end

  def save_tokens_to_file(tokens)
    tokens_file = ".schwab_tokens.json"

    print("\n💾 Save tokens to #{tokens_file}? (y/n): ")
    if gets.chomp.downcase == "y"
      File.write(tokens_file, JSON.pretty_generate(tokens))
      puts "✅ Tokens saved to #{tokens_file}"
      puts "⚠️  Remember to add #{tokens_file} to .gitignore!"
    end
  end

  def load_tokens_from_file
    tokens_file = ".schwab_tokens.json"
    return unless File.exist?(tokens_file)

    JSON.parse(File.read(tokens_file), symbolize_names: true)
  rescue => e
    puts "⚠️  Could not load tokens from file: #{e.message}"
    nil
  end
end

# Run the tester
if __FILE__ == $PROGRAM_NAME
  OAuthTester.new.run
end
