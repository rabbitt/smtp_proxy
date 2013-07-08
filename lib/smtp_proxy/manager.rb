require 'ostruct'
require 'singleton'

module SMTPProxy

  class Manager < ::Servolux::Server
    include Singleton

    attr_reader :listener

    def self.method_missing(method, *args, &block)
      return super unless instance.public_methods.include? method
      instance.public_send(method, *args, &block)
    end

    def initialize(options = {})
      super(
        SMTPProxy::APP_NAME,
        :pid_file => CommandLine.args.pid_file.to_s,
        :logger   => SMTPProxy.logger,
        :interval => 2,
      )

      @listener = Listener.new

      @pool = Servolux::Prefork.new(
        :module      => Proxy,
        :timeout     => nil,
        :min_workers => SMTPProxy.option(:children),
        :max_workers => SMTPProxy.option(:children)
      )
    end

    def log( msg )
      SMTPProxy.logger.info msg
    end

    def log_pool_status
      log "Pool status : #{@pool.worker_counts.inspect} living pids #{live_worker_pids.join(' ')}"
    end

    def live_worker_pids
      pids = []
      @pool.each_worker { |w| pids << w.pid if w.alive? }
      return pids
    end

    def shutdown_workers
      log "Shutting down all workers"
      @pool.stop
      loop do
        log_pool_status
        break if @pool.live_worker_count <= 0
        sleep 0.20
      end
    end

    def log_worker_status( worker )
      if not worker.alive? then
        worker.wait
        if worker.exited? then
          log "Worker #{worker.pid} exited with status #{worker.exitstatus}"
        elsif worker.signaled? then
          log "Worker #{worker.pid} signaled by #{worker.termsig}"
        elsif worker.stopped? then
          log "Worker #{worker.pid} stopped by #{worker.stopsig}"
        else
          log "I have no clue #{worker.inspect}"
        end
      end
    end


    #############################################################################
    # Implementations of parts of the Servolux::Server API
    #############################################################################

    # this is run once before the Server's run loop
    def before_starting
      log "Starting up the Pool"
      @pool.start( 1 )
      log "Send a HUP to reload configuration                 (kill -hup #{Process.pid})"
      log "Send a USR2 to kill all the workers                (kill -usr2 #{Process.pid})"
      log "Send a INT (Ctrl-C) or TERM to shutdown the server (kill -term #{Process.pid})"
    end

    # Add a worker to the pool when USR1 is received
    def hup
      shutdown_workers
      Config.reload!
      @pool.start(SMTPProxy.option(:children))
    end

    # kill all the current workers with a usr2, the run loop will respawn up to
    # the min_worker count
    #
    def usr2
      shutdown_workers
    end

    # By default, Servolux::Server will capture the TERM signal and call its
    # +shutdown+ method. After that +shutdown+ method is called it will call
    # +after_shutdown+ we're going to hook into that so that all the workers get
    # cleanly shutdown before the parent process exits
    def after_stopping
      shutdown_workers
    end

    # This is the method that is executed during the run loop
    #
    def run
      log_pool_status
      @pool.each_worker do |worker|
        log_worker_status( worker )
      end
      @pool.ensure_worker_pool_size
    end
  end
end