# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "benchmark-ips"
# Fix install issue for jruby on gem 3.1.8.
# No java stub is published.
gem "bigdecimal", "3.1.7" if RUBY_PLATFORM == "java"
