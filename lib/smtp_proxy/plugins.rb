require 'singleton'

module SMTPProxy
  module Plugin
  end

  class Plugins
    include Singleton

    def self.method_missing(method, *args, &block)
      return super unless instance.public_methods.include? method
      instance.public_send(method, *args, &block)
    end

    def initialize
      load_plugins
    end

    def load_plugins
      plugin_path = SMTPProxy.option(:plugin_path)

      (@plugins = config.plugins || []).each do |plugin|
        begin
          load  plugin_path + plugin
        rescue LoadError
          begin
            load plugin_path + "#{plugin}.rb"
          rescue LoadError
            SMTPProxy.logger.warn "Unable to load plugin #{plugin} - not found"
            next
          end
        end
        SMTPProxy.logger.info "Loaded plugin '#{plugin}'"
      end
    end

    def call_hooks(type, name, message)
      hook_name = "on_#{type}_#{name}".to_sym
      SMTPProxy.logger.info "Calling hook #{hook_name} for plugins"
      plugins.each do |plugin|
        plugin.public_send(hook_name, message) if plugin.respond_to? hook_name
      end
    end
  end
end