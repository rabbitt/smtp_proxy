require 'singleton'
require 'pp'

module SMTPProxy
  class Daemon < ::Servolux::Daemon
    include Singleton

    def self.method_missing(method, *args, &block)
      return super unless instance.public_methods.include? method
      instance.public_send(method, *args, &block)
    end

    def initialize()
      super(
        :server   => Manager.instance,
        :nochdir  => CommandLine.args.foreground,
        :noclose  => CommandLine.args.foreground,
      )
    end

    def foreground
      startup_command.startup
    end
  end
end