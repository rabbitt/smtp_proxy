require 'singleton'

module SMTPProxy
  class Daemon < ::Servolux::Daemon
    include Singleton

    def self.method_missing(method, *args, &block)
      return super unless instance.public_methods.include? method
      public_send(method, *args, &block)
    end

    def initialize()
      super(
        :server   => Manager.new,
        :name     => SMTPProxy::APP_NAME,
        :pid_file => CommandLine.args.pid_file,
        :nochdir  => CommandLine.args.foreground,
        :noclose  => CommandLine.args.foreground,
      )
    end

    def foreground
      Manager.new(
        :pid_file => CommandLine.args.pid_file,
        :name => SMTPProxy::APP_NAME
      ).startup
    end
  end
end