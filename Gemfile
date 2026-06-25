# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "benchmark-ips"
gem "rbs", "4.0.2" if RUBY_VERSION.start_with?("4.0")
# Fix install issue for jruby on gem 3.1.8.
# No java stub is published.
gem "bigdecimal", "3.1.7" if RUBY_PLATFORM == "java"
# rubocop-ast 1.49 removed EnsureNode#body, which the pinned RuboCop 1.64.1
# still calls; it errors on any file with an ensure block. Hold rubocop-ast
# back until RuboCop is upgraded.
gem "rubocop-ast", "< 1.49"
