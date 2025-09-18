source "https://rubygems.org"

gem "rails", "~> 8.0.2", ">= 8.0.2.1"
gem "propshaft"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "faraday", "~> 2.13"
gem "geocoder", "~> 1.8"
gem "tailwindcss-rails", "~> 2.0"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
  gem "sqlite3", ">= 2.1"
  gem "dotenv-rails", "~> 3.1"
  gem "rspec-rails", "~> 8.0"
end

group :test do
  gem "webmock", "~> 3.25"
end

group :production do
  gem "pg", "~> 1.1"
end