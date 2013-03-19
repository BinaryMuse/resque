require 'thor'
require "resque"

module Resque
  class CLI < Thor
    class_option :config,    :aliases => ["-c"], :type => :string
    class_option :redis,     :aliases => ["-R"], :type => :string
    class_option :namespace, :aliases => ["-N"], :type => :string

    desc "work", "Start processing jobs."
    option :queue,     :aliases => ["-q"], :type => :string,  :default => "*"
    option :require,   :aliases => ["-r"], :type => :string
    option :pid,       :aliases => ["-p"], :type => :string
    option :interval,  :aliases => ["-i"], :type => :numeric, :default => 5
    option :deamon,    :aliases => ["-d"], :type => :boolean, :default => false
    option :timeout,   :aliases => ["-t"], :type => :numeric, :default => 4.0
    #option :verbose,   :aliases => ["-v"], :type => :boolean, :default => false
    #option :vverbose,  :aliases => ["-vv"], :type => :boolean, :default => false
    def work
      load_config

      load_enviroment(Resque.config.require)
      worker = Resque::Worker.new(*Resque.config.queues)

      worker.term_timeout = Resque.config.timeout
      #worker.verbose = options[:verbose]
      #worker.very_verbose = options[:vverbose]

      if Resque.config.deamon
        Process.daemon(true)
      end

      if Resque.config.pid
        File.open(Resque.config.pid, 'w') { |f| f << worker.pid }
      end

      Resque.logger.info "Starting worker #{worker}"

      worker.work(Resque.config.interval) # interval, will block
    end

    desc "kill WORKER", "Kills a worker"
    def kill(worker)
      load_config

      before_action
      pid = worker.split(':')[1].to_i

      begin
        Process.kill("KILL", pid)
        puts "killed #{worker}"
      rescue Errno::ESRCH
        puts "worker #{worker} not running"
      end

      remove(worker)
    end

    desc "remove WORKER", "Removes a worker"
    def remove(worker)
      load_config

      Resque.remove_worker(worker)
      puts "Removed #{worker}"
    end

    desc "list", "Lists known workers"
    def list
      load_config

      if Resque.workers.any?
        Resque.workers.each do |worker|
          puts "#{worker} (#{worker.state})"
        end
      else
        puts "None"
      end
    end

    protected

      def load_config
        Resque.config = Resque::Config.new(YAML.load_file(File.expand_path(options[:config]))) if options[:config]
        Resque.config.redis = options[:redis] if options[:redis]
        Resque.config.namespace = options[:namespace] if options[:namespace]
      end

      def load_enviroment(file = nil)
        return if file.nil?

        if File.directory?(file) && File.exists?(File.expand_path("#{file}/config/application.rb"))
          require "rails"
          require File.expand_path("#{file}/config/environment.rb")
          if defined?(::Rails) && ::Rails.respond_to?(:application)
            # Rails 3
            ::Rails.application.eager_load!
          elsif defined?(::Rails::Initializer)
            # Rails 2.3
            $rails_rake_task = false
            ::Rails::Initializer.run :load_application_classes
          end
        else
          require File.expand_path(file)
        end
      end
  end
end
