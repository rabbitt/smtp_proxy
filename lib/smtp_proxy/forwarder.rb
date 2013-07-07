require 'socket'

module SMTPProxy
  class Forwarder
    DEFAULT_TIMEOUT = 30

    def initialize(options = {})
      @peer    = [ SMTPProxy.args.forwarder.address, SMTPProxy.args.forwarder.port ]
      @timeout = DEFAULT_TIMEOUT
      @socket = connect_to(*@peer, @timeout)
    end

    def connect_to(host, port, timeout=nil)
      ip_address = Socket.getaddrinfo(host, nil)[0][3]
      Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0).tap { |socket|
        if timeout
          secs = Integer(@timeout)
          usecs = Integer((@timeout - secs) * 1_000_000)
          optval = [secs, usecs].pack("l_2")
          socket.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
          socket.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
        end
        socket.connect(Socket.pack_sockaddr_in(port, ip_address))
      }
    end
    private :connect_to

    def close
      @socket.close
      @socket = nil
    end

    def hear
      reply = ''
      begin
        return nil unless temp = @socket.gets
        reply += temp
      end while temp =~ /^\d{3}-/

      reply.gsub(/\r\n$/, '')
    end

    def say(msg)
      return unless msg
      @socket.print "#{msg}\r\n"
    end

    def yammer(fd)
      @socket.print IO.read(fd)
    end
  end
end