module SMTPProxy
  module ProxyFilter
    extend self

    def before_executing
      max_requests_range = (SMTPProxy.option(:min_requests).to_i)..(SMTPProxy.option(:max_requests).to_i)
      @max_requests      = Random.rand(max_requests_range)
      @requests          = 0
      SMTPProxy.logger.info "Starting execution with max_request == #{@max_requests}"
    end

    def execute
      SMTPProxy.logger.info "Beginning execution"
      begin
        while (@requests += 1) <= @max_requests
          Manager.listener.proxy(Forwarder.new)

          if Process.ppid == 1
            SMTPProxy.logger.warn "Parent went away - shutting down"
            exit
          end
        end
      rescue StandardError => e
        SMTPProxy.logger.error "#{e.class.name}: #{e.message}: #{e.backtrace.first}"
      end
    end

    def after_executing
      SMTPProxy.logger.info "Shutting down"
    end
  end
end