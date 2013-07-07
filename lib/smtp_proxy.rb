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
  autoload :Logger,      'smtp_proxy/logger'
  autoload :Manager,     'smtp_proxy/manager'
  autoload :Version,     'smtp_proxy/version'

  LIB_PATH = Pathname.new(__FILE__).realpath.dirname
  APP_PATH = LIB_PATH.dirname
  APP_NAME = Pathname.new($0).basename

  def env
    ENV['SMTP_PROXY_ENV'] || CommandLine.args.env || 'production'
  end

  def log
    @logger ||= Logger.new
  end

  def option(name)
    args[name] || config[name]
  end

  def args
    CommandLine.instance.args
  end

  def config
    Config.instance
  end
end