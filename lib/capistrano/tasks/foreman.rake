namespace :foreman do
  desc <<-DESC
        Setup foreman configuration

        Configurable options are:

          set :foreman_roles, :all
          set :foreman_export_format, 'upstart'
          set :foreman_export_path, '/etc/init'
          set :foreman_flags, ''
          set :foreman_target_path, release_path
          set :foreman_app, -> { fetch(:application) }
          set :foreman_concurrency, 'web=2,worker=1' # default is not set
          set :foreman_log, -> { shared_path.join('log') }
          set :foreman_port, 3000 # default is not set
          set :foreman_user, 'www-data' # default is not set
          set :foreman_init_system, 'upstart' # other option is systemd
    DESC

  task :setup do
    invoke :'foreman:export'
    invoke :'foreman:start'
  end

  desc "Export the Procfile to another process management format"
  task :export do
    on roles fetch(:foreman_roles) do
      execute :mkdir, '-p', fetch(:foreman_export_path) unless test "[ -d #{fetch(:foreman_export_path)} ]"
      within fetch(:foreman_target_path, release_path) do

        options = {
          app: fetch(:foreman_app),
          log: fetch(:foreman_log)
        }
        # Foreman < 0.80.0 uses concurrency
        options[:concurrency] = fetch(:foreman_concurrency) if fetch(:foreman_concurrency)
        # Foreman >= 0.80.0 uses formation
        options[:formation] = fetch(:foreman_formation) if fetch(:foreman_formation)
        options[:port] = fetch(:foreman_port) if fetch(:foreman_port)
        options[:user] = fetch(:foreman_user) if fetch(:foreman_user)

        execute :foreman, 'export', fetch(:foreman_export_format), fetch(:foreman_export_path),
          options.map{ |k, v| "--#{k}='#{v}'" }, fetch(:foreman_flags)
      end
    end
  end

  %w(start stop restart enable disable).each do |action|
    desc "#{action.capitalize} the application services"
    task :"#{action}" do
      on roles fetch(:foreman_roles) do
        init_system_exec :"#{action}", fetch(:foreman_app)
      end
    end
  end

  def init_system_exec(action, app)
    case fetch(:foreman_init_system).to_sym
    when :upstart
      sudo(action, app)
    when :systemd
      sudo :systemctl, action, "#{app}.target"
    end
  end

end

namespace :load do
  task :defaults do
    set :foreman_roles, :all
    set :foreman_export_format, 'upstart'
    set :foreman_export_path, '/etc/init'
    set :foreman_flags, ''
    set :foreman_app, -> { fetch(:application) }
    set :foreman_log, -> { shared_path.join('log') }
    set :foreman_init_system, :upstart
  end
end
