GITHUB = Github.new(:oauth_token => ENV['GITHUB_OAUTH_TOKEN']) # Add a token to access private repos
GITHUB_WEBHOOK_SECRET = ENV['GITHUB_WEBHOOK_SECRET']
