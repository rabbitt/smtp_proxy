require 'singleton'
require 'pathname'
require 'yaml'

module SMTPProxy
  class Config
    include Singleton

    attr_accessor :config_path, :filter_path, :temp_path

    def self.method_missing(method, *args, &block)
      return super unless instance.respond_to? method
      instance.send(method, *args, &block)
    end

    def initialize()
      @config_path = CommandLine.args.config_path
      @filter_path = CommandLine.args.filter_path
      @temp_path   = CommandLine.args.queue_path

      reconfigure!
    end

    def reconfigure!
      config = YAML.load(IO.read(@config_path)).to_ostruct
      @config = config[DaemonKit.env] || config
      self
    end
    alias :reload! :reconfigure!

    def method_missing(method, *args, &block)
      return super unless @config.public_methods.include? method
      @config.public_send(method, *args, &block)
    end

    def respond_to?(method, include_private = false)
      return true if @config[method]
      super
    end
  end
end
