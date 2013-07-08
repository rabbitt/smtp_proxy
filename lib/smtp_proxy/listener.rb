require 'thread'
require 'socket'
require 'tempfile'
require 'state_machine'

module SMTPProxy
  class Listener
    TOKEN_HELO      = /^(?:helo|ehlo)\s+(.+)/i
    TOKEN_RSET      = /^rset\s*/i
    TOKEN_MAIL_FROM = /^mail\s+from:\s*(?:<([^>]+)>|(.+))/i
    TOKEN_RCPT_TO   = /^rcpt\s+to:\s*(?:<([^>]+)>|(.+))/i
    TOKEN_DATA      = /^data/i

    state_machine :initial => :waiting do
      event(:greet) { transition :waiting => :helo }
      event(:identify_sender) { transition :helo => :mail_from }
      event(:identify_recipient) { transition :mail_from => :rcpt_to, :rcpt_to => same }
      event(:send_data) { transition :rcpt_to => :data }
      event(:done) { transition :data => :finished }
      event(:reset) { transition any => :waiting }

      before_transition all => any do |listener, transition|
        Plugins.call_hooks(:before, transition.event, listener)
      end

      after_transition all => any do |listener, transition|
        Plugins.call_hooks(:after, transition.event, listener)
      end
    end

    state_machine :trace, :initial => :disabled, :namespace => 'trace' do
      event(:enable) { transition all => :enabled }
      event(:disable) { transition all => :disabled }
      state :enabled,  :value => true
      state :disabled, :value => false
    end

    def initialize
      @server = TCPServer.new(SMTPProxy.args.listener.address, SMTPProxy.args.listener.port)
      @client = nil
      @trace  = false
      @state  = :waiting
      @debug  = $stderr
    end

    def proxy(endpoint)
      begin
        message    = Message.new
        @client    = @server.accept
        @forwarder = Forwarder.new

        until finished?
          unless data?
            return fail unless (line = getline)
            line = line.gsub(/\s+$/, '').gsub(/\s+/, ' ')
            case line
              when TOKEN_HELO then greet!(message, line)
              when TOKEN_MAIL_FROM then identify_sender!(message, line)
              when TOKEN_RCPT_TO then identify_recipient!(message, line)
              when TOKEN_DATA then send_data!(message)
              when TOKEN_RSET then reset!(message)
            end
          end
          @forwarder.say greet!(message, line) if waiting?
          @forwarder.say
        end
      ensure
        @forwarder.close
        @forwarder = nil
      end
    end

    def chat
      while true
        if @state !~ /^data/i
          return 0 unless (line = getline)
          line.gsub!(/[\r\n]+$/, '')
          @state = line
          case line
            when TOKEN_HELO then
              greet!
              message.helo = $1.gsub(/\s+$/, '').gsub(/\s+/, ' ')
            when TOKEN_RSET then
              message.reset
            when TOKEN_MAIL_FROM then
              message.reset
              message.from = $1.gsub(/\s+$/, '')
            when TOKEN_RCPT_TO then
              message.to = $1.gsub(/\s+$/, '').gsub(/\s+/, ' ')
            when TOKEN_DATA then
              message.to = message.recipients
          end
        else
          if message.data.is_a? File
            message.data.rewind
            message.data.truncate(0)
          else
            message.data = Tempfile.new($$)
          end
          while line = getline
            if ".\r\n" == line
              message.data.rewind
              return @state = '.'
            end
            line.gsub(/^\.\./, '.')
            message.data.print line
          end
        end
      end

      return message
    end

    def getline
      begin
        @client.gets.tap { |line|
          @debug.puts "C: #{line}" if @debug
        }
      rescue
        nil
      end
    end

    def print(message)
      @client.print message
      @debug.puts "S: #{message}"
    end

    def ok(message = nil)
      message ||= '250 ok.'
      print "#{message}\r\n"
    end

    def fail(message = nil)
      message ||= '550 no.'
      print "#{message}\r\n"
    end
  end
end
