# frozen_string_literal: true

source 'https://rubygems.org'

# Only define Ruby version once
ruby file: '.tool-versions'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'dotenv'
gem 'httparty'
gem 'logger'
gem 'open3'
gem 'rubocop'
