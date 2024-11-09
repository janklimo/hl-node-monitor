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

    if jailed?
      @logger.info 'Validator jailed, unjailing...'
      execute_unjail_command
    else
      @logger.info 'Validator is purring.'
    end
  end

  private

  def setup_logging
    # Create logs directory if it doesn't exist
    FileUtils.mkdir_p('logs')

    # Create a log file with today's date
    log_file = File.join('logs', "validator_#{Time.now.strftime('%Y%m%d')}.log")

    # Create a multi-logger that writes to both STDOUT and file
    @logger = Logger.new(MultiIO.new($stdout, File.open(log_file, 'a')))
    @logger.level = Logger::INFO

    # Customize the log format
    @logger.formatter = proc do |severity, datetime, _progname, msg|
      date_format = datetime.strftime('%Y-%m-%d %H:%M:%S')
      "[#{date_format}] #{severity}: #{msg}\n"
    end
  end

  def jailed?
    node = validators_data.detect { |data| data['validator'] == ENV['VALIDATOR'] }

    unless node
      @logger.warn "Validator #{ENV['VALIDATOR']} not found in validators data"
      return false
    end

    node['isJailed']
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

# Helper class to write to multiple IO objects
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
