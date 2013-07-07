require 'thread'
require 'socket'
require 'tempfile'

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
      @recipients << (@to = recipient)
    end

    alias :to :rcpt_to
    alias :to= :rcpt_to=
    alias :from :mail_from
    alias :from= :mail_from=
  end

  class Listener
    attr_reader :incoming

    TOKEN_HELO      = /^(?:helo|ehlo)\s+(.+)/i
    TOKEN_RSET      = /^rset\s*/i
    TOKEN_MAIL_FROM = /^mail\s+from:\s*(?:<([^>]+)>|(.+))/i
    TOKEN_RCPT_TO   = /^rcpt\s+to:\s*(?:<([^>]+)>|(.+))/i
    TOKEN_DATA      = /^data/i

    def initialize()
        @incoming = Queue.new
        @server   = TCPServer.new(args.listener.address, args.listener.port)
        @state    = 'bound'
        @peer     = nil
        @client   = nil
        @debug    = $stderr
    end

    def args
      SMTPProxy.args
    end

    def accept
      @client = @server.accept.tap { |client|
        @peer = client.peeraddr
        @state = 'accepted'
      }
    end

    def get_message
      message = Message.new

      while true
        if @state !~ /^data/i
          return 0 unless (line = getline)
          line.gsub!(/[\r\n]+$/, '')
          @state = line
          case line
            when TOKEN_HELO then
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
