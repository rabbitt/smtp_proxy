#!/usr/bin/env ruby

require 'optparse'
require 'pathname'
require 'yaml'
require 'singleton'

require 'tmpdir'
require 'tempfile'

require 'smtp_proxy/core_ext/ostruct'

require 'awesome_print'

module SMTPProxy
  class CommandLine
    include Singleton

    attr_reader :parser, :args
    private :parser

    DEFAULT_OPTIONS = {
      :config_path  => Pathname.new('/etc/smtp_proxy'),
      :filter_path  => Pathname.new('/etc/smtp_proxy/filters'),
      :pid_file     => Pathname.new('/var/run/smtp_proxy/smtp_proxy.pid'),
      :queue_path   => Dir.tmpdir,
      :children     => 16,
      :min_requests => 100,
      :max_requests => 200,
      :debug_trace  => false,
      :foreground   => false
    }.freeze

    def self.method_missing(method, *args, &block)
      return super unless instance.respond_to? method
      instance.send(method, *args, &block)
    end

    def initialize()
      @args = OpenStruct.new(DEFAULT_OPTIONS)
      parse!
    end

    def usage(message = nil)
      $stderr.puts message unless message.nil?
      $stderr.puts parser.help
    end

    def validate!(exit_on_fail = false)
      unless @args.args.size == 2
        usage "Must provide both listen and forward addresses!"
        exit_on_fail ? exit!(1) : (return false)
      end

      listen  = @args.args[0].split(':').tap { |v| v[1] = Integer(v[1]) rescue 0 }
      forward = @args.args[1].split(':').tap { |v| v[1] = Integer(v[1]) rescue 0 }

      if listen[1] <= 0 && forward[1] <= 0
        usage "Must provide a listen /and/ forward port!"
        exit_on_fail ? exit!(1) : (return false)
      elsif listen[0] == forward[0] && listen[1] == forward[1]
        usage "Forward and listening port are the same, on the same host!"
        exit_on_fail ? exit!(1) : (return false)
      end
    end

    def method_missing(method, *args, &block)
      return super unless @args.public_methods.include? method
      @args.public_send(method, *args, &block)
    end

    def respond_to?(method, include_private = false)
      return true if @args[method]
      super
    end

    def inspect
      id = self.class.name.to_s.split('::').last + ':' + ("0x%014x" % (object_id << 1))
      "<#{id} @args=#{@args.inspect}>"
    end

    def to_s
      id = self.class.name.to_s.split('::').last + ':' + ("0x%014x" % (object_id << 1))
      "<#{id} @args=#{@args.inspect}>"
    end

    private

    def parse!(validate = false, exit_on_fail = false)
      config_path_set = false
      queue_path_set  = false
      filter_path_set = false

      @parser = OptionParser.new("Usage: #{APP_NAME} [options] <listen-address:port> <forward-address:port>") do |parser|
        parser.separator 'General'
        parser.separator 'Paths'
        parser.on('-c PATH', '--config-path PATH', %Q(Configuration path. Default: #{@args.config_path})) {|v| config_path_set = true; @args.config_path = v }
        parser.on('-f PATH', '--filter-path PATH', %Q(Plugin path. Default: #{@args.filter_path})) { |v| filter_path_set = true; @args.filter_path = v }
        parser.on('-t PATH', '--queue-path PATH', %Q(Queue file path. Default: #{@args.queue_path})) { |v| queue_path_set = true; @args.queue_path = v }
        parser.on('-p FILE', '--pid-file FILE', %Q(Path to pid file. Default: #{@args.pid_file})) { |v| @args.pid_file = v }
        parser.separator 'Run Time'
        parser.on('-e' ,'--environment ENV', %Q(Environment)) { |v| @args.environment = v }
        parser.on('-F' ,'--foreground', %Q(Don't daemonize.)) { |v| @args.foreground = true }
        parser.on('-C', '--children CHILDREN', %Q(Maximum children processes to run. Default: #{@args.children})) { |v| @args.children = Integer(v) }
        parser.on('-M', '--max-requests CHILDREN', %Q(Maximum requests to handle before restarting. Default: #{@args.max_requests})) { |v| @args.max_requests = Integer(v) }
        parser.on('-m', '--min-requests CHILDREN', %Q(Minimum requests to handle before restarting. Default: #{@args.min_requests})) { |v| @args.min_requests = Integer(v) }
        parser.on('-d', '--debug-trace PATH', %Q(Path to debug log file. Default: #{@args.debug_trace.inspect})) { |v| @args.debug_trace = !!v }
        parser.separator 'Misc'
        parser.on('-h', '--help', 'This message') { puts parser.help; exit! 0 }
        parser.separator ''
        parser.parse!

        @args.args = ARGV.dup
      end

      if config_path_set
        @args.filter_path = Pathname.new(@args.config_path) + 'filters' unless filter_path_set
        @args.queue_path   = Pathname.new(@args.config_path) + 'tmp' unless queue_path_set
      end

      validate!(defined?(IRB) ? false : true)

      @args.listener = OpenStruct.new( Hash[[:address, :port].zip(@args.args[0].split(':').tap {|v| v[1] = v[1].to_i})] )
      @args.forwarder = OpenStruct.new( Hash[[:address, :port].zip(@args.args[1].split(':').tap {|v| v[1] = v[1].to_i})] )

      self
    end
  end
end
