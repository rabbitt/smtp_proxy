require 'pathname'
require 'servolux'
require 'smtp_proxy/core_ext'

module SMTPProxy
  extend self

  autoload :CommandLine, 'smtp_proxy/command_line'
  autoload :Config,      'smtp_proxy/config'
  autoload :Daemon,      'smtp_proxy/daemon'
  autoload :Forwarder,   'smtp_proxy/forwarder'
  autoload :Listener,    'smtp_proxy/listener'
  autoload :Manager,     'smtp_proxy/manager'
  autoload :Message,     'smtp_proxy/message'
  autoload :Plugin,      'smtp_proxy/plugins'
  autoload :Plugins,     'smtp_proxy/plugins'
  autoload :Proxy,       'smtp_proxy/proxy'
  autoload :Version,     'smtp_proxy/version'

  LIB_PATH = Pathname.new(__FILE__).realpath.dirname
  APP_PATH = LIB_PATH.dirname
  APP_NAME = Pathname.new($0).basename.to_s

  def env
    ENV['SMTP_PROXY_ENV'] || CommandLine.args.env || 'production'
  end

  def logger
    @logger ||= args.foreground ? Logger.new($stderr) : Logger.new(option(:log_file))
  end

  def option(name)
    args[name] || args.general[name] || config[name]
  end

  def args
    CommandLine.instance.args
  end

  def config
    Config.instance
  end
end