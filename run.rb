# frozen_string_literal: true

require 'open3'
require 'logger'
require 'dotenv'
require 'httparty'
require 'json'
require 'fileutils'

Dotenv.load

class Runner
  def initialize
    setup_logging
  end

  def run
    @logger.info "Starting validator check at #{Time.now}"

    status = check_validator_status
    if status[:jailed]
      handle_jailed_status(status[:unjailable_after])
    else
      @logger.info 'Validator is purring.'
    end
  end

  private

  def setup_logging
    FileUtils.mkdir_p('logs')
    log_file = File.join('logs', "validator_#{Time.now.strftime('%Y%m%d')}.log")
    @logger = Logger.new(MultiIO.new($stdout, File.open(log_file, 'a')))
    @logger.level = Logger::INFO
    @logger.formatter = proc do |severity, datetime, _progname, msg|
      date_format = datetime.strftime('%Y-%m-%d %H:%M:%S')
      "[#{date_format}] #{severity}: #{msg}\n"
    end
  end

  def check_validator_status
    node = validators_data.detect { |data| data['validator'] == ENV['VALIDATOR'] }
    unless node
      @logger.warn "Validator #{ENV['VALIDATOR']} not found in validators data"
      return { jailed: false, unjailable_after: nil }
    end

    { jailed: node['isJailed'], unjailable_after: node['unjailableAfter'] }
  end

  def handle_jailed_status(unjailable_after)
    if unjailable_after.nil?
      @logger.warn 'Validator is jailed but unjailableAfter is not set'
      return
    end

    current_time = (Time.now.to_f * 1000).to_i # Convert to milliseconds
    if current_time < unjailable_after
      @logger.info "Validator is jailed. Waiting until unjailable (at #{Time.at(unjailable_after / 1000)})"
    else
      @logger.info 'Validator is jailed and unjail period has passed. Executing unjail command...'
      execute_unjail_command
    end
  end

  def validators_data
    url = 'https://api.hyperliquid-testnet.xyz/info'
    headers = { 'Content-Type' => 'application/json' }
    body = { type: 'validatorSummaries' }.to_json
    @logger.debug "Fetching validators data from #{url}"
    response = HTTParty.post(url, headers:, body:)
    if response.success?
      @logger.debug 'Successfully retrieved validators data'
      response
    else
      @logger.error "Failed to fetch validators data: #{response.code} - #{response.body}"
      []
    end
  end

  def execute_unjail_command
    key = ENV['KEY']
    command = "~/hl-node --chain Testnet --key #{key} send-signed-action '{\"type\": \"CSignerAction\", \"unjailSelf\": null}'"
    begin
      @logger.info 'Executing unjail command...'
      stdout, stderr, status = Open3.capture3(command)
      if status.success?
        @logger.info 'Unjail command executed successfully'
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

class MultiIO
  def initialize(*targets)
    @targets = targets
  end

  def write(*args)
    @targets.each { |t| t.write(*args) }
  end

  def close
    @targets.each(&:close)
  end
end

runner = Runner.new
runner.run
