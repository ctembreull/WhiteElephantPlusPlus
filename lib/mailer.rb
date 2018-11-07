require 'net/smtp'

class Mailer
  class NoEmailException < Exception; end

  attr_reader :distro
  def initialize(config:)
    @config = config
    @distro = Hash.new
    @sender_method = nil
  end

  def live(data)
    @sender_method = :send_email
    @distro.merge!(data.reject{|k,v| v[:email].empty? || v[:email].nil?})
    self
  endrequire

  def test(data)
    @sender_method = :display_email
    @distro.merge!(data)
    self
  end

  def send_all(rcp_list)
    log(" => Starting send_all")
    rcp_list.each do |k|
      self.send(@sender_method, @distro[k.to_sym])
    end
    log(" <= email send_all done.")
  end

  def send_email(recipient)
    log("Generating email to #{recipient[:id]} <#{recipient[:email]}>")
    ns = create_binding(recipient)
    template = File.read(File.open(@config['default_template'], 'r'))
    message = ERB.new(template).result(ns.get_binding)
    log(message)

    begin
      Net::SMTP.start(@config['smtp_host'], 587, @config['smtp_helo'], @config['smtp_username'], @config['smtp_password'], :login) do |smtp|
        smtp.send_message message, @config['smtp_sender_email'], recipient[:email]
      end
      log("Email successfully sent.")
    rescue Exception => ex
      log("Unable to send mail: #{ex.message}")
      raise
    end
  end

  def display_email(recipient)
    log("Displaying message for #{recipient[:id]}")
    ns = create_binding(recipient)
    template = File.read(File.open(@config['default_template'], 'r'))
    message = ERB.new(template).result(ns.get_binding)
    log(message)
  end

  def create_binding(recipient)
    giftee = recipient[:giftee]
    giftee = @distro[giftee]
    data = {
      from: "#{@config['smtp_sender_name']} <#{@config['smtp_sender_email']}>",
      to: recipient[:email],
      year: Time.now.strftime("%Y"),
      gifter_name: recipient[:name],
      giftee_name: giftee[:name],
      signature: "#{@config['smtp_sender_name']} | #{@config['smtp_sender_email']}",
      unique_id: OPTIONS.mode == 'test' ? @config['unique_id'] : '',
      reminder: OPTIONS.mode == 'remind' ? ' Reminder' : '',
      test: OPTIONS.mode == 'test' ? ' TEST' : ''
    }
    ::Namespace.new(data)
  end

  def log(message)
    LOGGER.log("[mailer] #{message}")
  end
end
