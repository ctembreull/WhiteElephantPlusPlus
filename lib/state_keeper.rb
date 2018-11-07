class StateKeeper
  class EventNotFoundError < Exception; end
  class EventAlreadyExistsError < Exception; end

  def initialize(config:, state:)
    @config = config
    @statefile = "#{@config['state_path']}/#{OPTIONS.event}.state"
    @state = state
  end

  def exists?(config, raise_on_exists = true)
    statefile = "#{config['state_path']}/#{event}.state"
    if File.exists?(statefile) && raise_on_exists
      raise EventAlreadyExistsError.new("The event (#{OPTIONS.event}) already exists and cannot be overwritten")
    end
    true
  end

  def self.load(config, event)
    statefile = "#{config['state_path']}/#{event}.state"
    raise EventNotFoundError.new("Unable to find state for event #{event}") unless File.exists?(statefile)
    state = JSON.parse(File.read(statefile)).deep_symbolize_keys
    return StateKeeper.new(config: config, state: state)
  end

  def self.all(config:)
    events = []
    begin
      return events unless File.exists?(config['state_path'])
      dir = Dir.new(config['state_path'])
      dir.entries.each do |e|
        next if ['.', '..'].include? e
        events << e.sub('.state', '')
      end
    end
    events
  end

  def save
    unless File.exists?(@config['state_path'])
      Dir.mkdir(@config['state_path'])
      log("State directory #{@config['state_path']} did not exist, and has been created")
    end

    unless File.exists?(@statefile)
      File.open(@statefile, 'w+') do |file|
        file.write(JSON.pretty_generate(@state))
      end
      log("State file #{@statefile} written.")
    else
      log("State file #{@statefile} existed already, not overwriting.")
    end
  end

  def to_h
    @state
  end

  def for_key(key:)
    return @state if @state.nil?
    @state[key]
  end

  def log(message)
    LOGGER.log("[statekeeper] #{message}")
  end
end
