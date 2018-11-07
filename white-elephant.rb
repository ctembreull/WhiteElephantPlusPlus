#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'optparse'
require 'net/smtp'
require 'yaml'
require 'json'
require 'erb'
require 'ostruct'
require 'time'
require 'securerandom'

# debugging tools
require 'pp'
require 'byebug'

# local libraries
require 'patches'
require 'namespace'
require 'logger'
require 'distribution'
require 'mailer'
require 'state_keeper'


# load configuration here as a constant
LOGGER = Logger.new
CONFIG = JSON.parse(File.read('./config/config.json')).deep_symbolize_keys.freeze
RUNTIME = Time.now.iso8601
CONFIG_PATH = './config'
OPTIONS = OpenStruct.new(
  event: nil,
  mode: 'test',
  config_path: "#{CONFIG_PATH}/config.json",
  template: "#{CONFIG_PATH}/default_template.erb",
  verbose: false
)

parser = OptParse.new do |opts|
  opts.banner = "\nUsage: gifts.rb [options]"
  opts.on("-e", "--event [NAME]", String, "The name of the event to create a gift exchange for") do |e|
    OPTIONS.event = e
  end
  opts.on("-l", "--list", "Show a list of all past events") do |e|
    OPTIONS.mode = 'list'
  end
  opts.on("-r", "--remind [NAME]", String, "An id for a person to resend an email to") do |r|
    OPTIONS.mode = 'remind'
    OPTIONS.remind = r
  end
  opts.on("-t", "--template [FILENAME]", String, "The path to a template to base all sent emails on") do |t|
    OPTIONS.template = "#{CONFIG_PATH}/#{t}"
  end
  opts.on("-v", "--verbose", "Show debug logging at runtime") do |v|
    OPTIONS.verbose = true
  end
  opts.on("-x", "--execute", String, "Create exchange and send emails for real.") do |x|
    OPTIONS.mode = 'live'
  end
end.parse!

class WhiteElephantPlusPlus
  class NoEventError < Exception; end
  def initialize
    @unique_id = SecureRandom.uuid
    @config ||= JSON.parse(File.read(OPTIONS.config_path))
    LOGGER.configure(config: @config['logger'].merge('unique_id' => @unique_id))
    @distro = Distribution.new(config: @config['distribution'])
    @mailer = Mailer.new(config: @config['mailer'].merge('unique_id' => @unique_id))
  end

  def run
    log("Run #{@unique_id} begins in #{OPTIONS.mode} mode:")

    unless %w(list remind).include? OPTIONS.mode
    end

    case OPTIONS.mode
    when 'list'
      log("showing list of all events (might help!)")
      events = StateKeeper.all(config: @config['statekeeper'])
      puts events.join("\n")
    when 'remind'
      state = ::StateKeeper.load(@config['statekeeper'], OPTIONS.event)
      @distro.load_state(state.to_h)
      log("Sending reminder email to #{OPTIONS.remind}")
      @mailer.live(@distro.to_h).send_email(@distro.to_h[OPTIONS.remind.to_sym])
    when 'live'
      StateKeeper.exists?(config: @config['statekeeper'])
      @distro.build
      log("Really actually sending emails to everyone. Be afraid.")
      @mailer.live(@distro.to_h).send_all(@distro.live_recipients)
      ::StateKeeper.new(config: @config['statekeeper'], state: @distro.to_pairs).save
    when 'test'
      @distro.build
      log("Sending test emails to #{@distro.test_recipients}")
      @mailer.live(@distro.to_h).send_all(@distro.test_recipients)
      ::StateKeeper.new(config: @config['statekeeper'], state: @distro.to_pairs).save
    else
      log("Unknown mode: #{OPTIONS.mode}; terminating")
    end

    log("Run ends.")
    LOGGER.save
  end

  def log(message)
    LOGGER.log("[main] #{message}")
  end
end

if OPTIONS.event.nil? && OPTIONS.mode != 'list'
  raise WhiteElephantPlusPlus::NoEventError.new("No event name specified. Use --list if you want to see the ones you already have.")
end

begin
  giftex = WhiteElephantPlusPlus.new.run
rescue Exception => ex
  LOGGER.log("[main] #{ex.message}")
  LOGGER.save
  raise
end
