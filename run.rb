# frozen_string_literal: true

require 'open3'
require 'logger'
require 'dotenv'
require 'httparty'
require 'json'

Dotenv.load

class Runner
  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
  end

  def run
    if jailed?
      @logger.info 'Validator jailed, unjailing...'
      execute_unjail_command
    else
      @logger.info 'Validator is purring.'
    end
  end

  private

  def jailed?
    node = validators_data.detect { |data| data['validator'] == ENV['VALIDATOR'] }

    return false unless node

    node['isJailed']
  end

  def validators_data
    url = 'https://api.hyperliquid-testnet.xyz/info'
    headers = { 'Content-Type' => 'application/json' }
    body = { type: 'validatorSummaries' }.to_json

    HTTParty.post(url, headers:, body:)
  end

  def execute_unjail_command
    key = ENV['KEY']
    command = "~/hl-node --chain Testnet --key #{key} send-signed-action '{\"type\": \"CSignerAction\", \"unjailSelf\": null}'"

    begin
      stdout, stderr, status = Open3.capture3(command)

      if status.success?
        @logger.info 'Command executed successfully'
        @logger.info "Output: #{stdout}"
        true
      else
        @logger.error "Command failed with status: #{status.exitstatus}"
        @logger.error "Error: #{stderr}"
        false
      end
    rescue StandardError => e
      @logger.error "Exception occurred while executing command: #{e.message}"
      @logger.error e.backtrace.join("\n")
      false
    end
  end
end

runner = Runner.new
runner.run
