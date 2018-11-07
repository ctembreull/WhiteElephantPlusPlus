require 'time'

class Logger
  class NotConfiguredError < Exception; end

  def initialize(config: {})
    @config = {}.merge(config)
    @log = []
  end

  def configure(config: {})
    @config.merge!(config)
  end

  def log(message)
    @log << message
    puts "LOG: #{message}" if OPTIONS.verbose
  end

  def save
    raise NotConfiguredError.new if @config.empty?
    Dir.mkdir(@config['log_path']) unless File.exists?(@config['log_path'])
    File.open("#{@config['log_path']}/#{OPTIONS.event}.log", "w") do |file|
      file.write "\n\n#{Time.now.iso8601} ========================================\n\n"
      file.write(to_s)
    end
  end

  def to_s
    @log.join("\n")
  end
end
