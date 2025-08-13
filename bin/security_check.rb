#!/usr/bin/env ruby
# frozen_string_literal: true

# Security check script to ensure no secrets are committed

require "json"

puts "🔐 Security Check for Schwab SDK"
puts "=" * 50

# Check 1: Verify .gitignore entries
puts "\n1. Checking .gitignore..."
required_ignores = [".env", ".schwab_tokens.json", "spec/fixtures/vcr_cassettes/"]
gitignore = File.read(".gitignore")
missing = required_ignores.reject { |pattern| gitignore.include?(pattern) }

if missing.empty?
  puts "   ✅ All sensitive patterns are in .gitignore"
else
  puts "   ❌ Missing from .gitignore: #{missing.join(", ")}"
end

# Check 2: Verify files are actually ignored
puts "\n2. Verifying files are ignored by git..."
sensitive_files = [".env", ".schwab_tokens.json"]
tracked = sensitive_files.select do |file|
  File.exist?(file) && system("git ls-files --error-unmatch #{file} 2>/dev/null")
end

if tracked.empty?
  puts "   ✅ No sensitive files are tracked by git"
else
  puts "   ❌ These files are tracked: #{tracked.join(", ")}"
end

# Check 3: Check for hardcoded secrets in code
puts "\n3. Scanning for hardcoded secrets..."
patterns = [
  /client_id\s*=\s*["'][^"']+["']/i,
  /client_secret\s*=\s*["'][^"']+["']/i,
  /api_key\s*=\s*["'][^"']+["']/i,
  /password\s*=\s*["'][^"']+["']/i,
  /token\s*=\s*["'][A-Za-z0-9_\-]{20,}/,
]

suspicious = []
Dir.glob("**/*.rb").each do |file|
  next if file.start_with?("spec/", "doc/", "coverage/", ".yardoc/")

  content = File.read(file)
  patterns.each do |pattern|
    if content.match?(pattern) && !content.match?(/ENV\[/)
      suspicious << "#{file}: potential hardcoded secret"
    end
  end
end

if suspicious.empty?
  puts "   ✅ No hardcoded secrets found in Ruby files"
else
  puts "   ❌ Potential issues found:"
  suspicious.each { |s| puts "      - #{s}" }
end

# Check 4: Check if .env.example exists and .env doesn't contain real values
puts "\n4. Checking .env files..."
if File.exist?(".env.example")
  puts "   ✅ .env.example exists for reference"
else
  puts "   ⚠️  No .env.example file found"
end

if File.exist?(".env")
  env_content = File.read(".env")
  if env_content.include?("your_") || env_content.include?("xxx")
    puts "   ⚠️  .env appears to contain placeholder values"
  else
    puts "   ⚠️  .env exists - ensure it contains only test values"
  end
end

# Check 5: Check commit history
puts "\n5. Checking recent commits..."
recent_commits = %x(git log --oneline -10 2>/dev/null).lines
suspicious_commits = recent_commits.select do |commit|
  commit.match?(/\b(secret|token|key|password|credential)\b/i)
end

if suspicious_commits.empty?
  puts "   ✅ No suspicious commit messages"
else
  puts "   ⚠️  Review these commits:"
  suspicious_commits.each { |c| puts "      - #{c.strip}" }
end

puts "\n" + "=" * 50
puts "Security check complete!"
puts "\nRemember to:"
puts "- Never commit real API credentials"
puts "- Use environment variables for all secrets"
puts "- Review VCR cassettes before committing"
puts "- Keep .gitignore updated"
