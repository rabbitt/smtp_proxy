module SMTPProxy
  class Message
    attr_accessor :recipients, :rcpt_to, :data, :mail_from, :helo

    def initialize()
      @helo = nil
      reset
    end

    def reset()
      @recipients = []
      @mail_from  = nil
      @rcpt_to    = nil
      @data       = nil
    end

    def rcpt_to=(recipient)
      @recipients << recipient
    end

    alias :to :rcpt_to
    alias :to= :rcpt_to=
    alias :from :mail_from
    alias :from= :mail_from=
  end
end