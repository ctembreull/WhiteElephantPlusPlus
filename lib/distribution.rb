class Distribution
  class NoCandidateException < Exception; end
  class InvalidListException < Exception; end

  def initialize(config:)
    @max_attempts = 25
    @attempts = 0
    @distro = config.deep_symbolize_keys
    distro.each do |k,v|
      @distro[k] = v.merge(assigned: false, giftee: '')
    end

    # When running tests, all emails should be sent to either the administrator
    # or to any accounts designated as test accounts. To accomplish this, overwrite
    # the email setting for any non-admin and non-test users with the email address
    # of the admin user.
    if OPTIONS.mode != 'live'
      admin = @distro.select{|k,v| v if v[:admin]}.keys.first
      @distro.each do |k,v|
        @distro[k][:email] = @distro[admin][:email] unless (v[:test] || v[:admin])
      end
    end
  end

  def log(message)
    LOGGER.log("[distribution] #{message}")
  end

  def build
    log(" => Building exchange distribution:")
    log("list contains #{@distro.keys.length} keys")
    begin
      @distro.keys.shuffle.each do |id|
        giftee = get_assignment_for(id)
        @distro[giftee.to_sym][:assigned] = true
        @distro[id][:giftee] = giftee.to_sym
      end
    rescue NoCandidateException => ex
      log("Error: No candidate found (#{ex.message})")
      if (@attempts += 1) < @max_attempts
        reset!
        retry
      end
    end
    log("<= Distribution built successfully")
  end

  def load_state(state)
    # 1. discard any distro entries without state entries
    @distro.keys.each do |k|
      @distro.delete!(k) unless state.keys.include?(k.to_sym)
    end

    # 2. fill the distro with the gift pairings in state
    state.each do |k,v|
      @distro[k.to_sym][:giftee] = v.to_sym
      @distro[v.to_sym][:assigned] = true
    end
  end

  def valid?
    (@distro.values.reject{|o| (!!o[:assigned] || !o[:giftee].empty?)}).empty?
  end

  def reset!
    @distro.values.each do |v|
      v[:assigned] = false
      v[:giftee] = nil
    end
    log("Distribution reset")
  end

  def to_a
    @distro.values.map{|v| "#{v[:name]} => #{@distro[v[:giftee]][:name]}"}
  end

  def to_s
    to_a.join("\n")
  end

  def to_h
    @distro
  end

  def to_pairs
    @distro.values.map{|v| [v[:id], v[:giftee].to_s]}.to_h
  end

  def test_recipients
    #@distro.reject{|k,v| !v[:test]}.keys.map(&:to_s)
    @distro.keys.map(&:to_s)
  end

  def live_recipients
    @distro.reject{|k,v| v[:email].empty?}.keys.map(&:to_s)
  end

  def get_assignment_for(id)
    giftee = get_candidates_for(id).sample
    log("Selected giftee for #{id} => #{giftee}")
    raise NoCandidateException.new("(#{@attempts + 1}) No giftee found for #{@distro[id][:name]}") if giftee.to_s.empty?
    giftee
  end
  private :get_assignment_for

  def get_candidates_for(id)
    candidates =  @distro.values.reject{|v| (id.to_s == v[:id] || !!v[:assigned] || @distro[id][:blacklist].include?(v[:id]))}.map{|c| c[:id]}
    log("candidates for #{id} => #{candidates.join(',')}")
    raise NoCandidateException.new("(#{@attempts + 1}) No candidates found for #{@distro[id][:name]}") if candidates.empty?
    candidates
  end
  private :get_candidates_for

  def to_recursive_ostruct(hash)
    OpenStruct.new(hash.each_with_object({}) do |(key, val), memo|
      memo[key] = val.is_a?(Hash) ? to_recursive_ostruct(val) : val
    end)
  end
  private :to_recursive_ostruct
end
