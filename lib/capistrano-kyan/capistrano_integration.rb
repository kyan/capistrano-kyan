require 'capistrano'
require 'capistrano/version'

module CapistranoKyan
  class CapistranoIntegration
    TASKS = [
      'kyan:db:setup',
      'kyan:vhost:setup'
    ]

    def self.load_into(capistrano_config)
      capistrano_config.load do
        before(CapistranoIntegration::TASKS) do
          _cset(:app_env)                    { (fetch(:rails_env) rescue 'staging') }
        end

        def appize(app, prefix = 'staging')
          "#{app.gsub('.','_')}_#{prefix}"
        end

        #
        # vhost cap tasks
        #
        namespace :kyan do
          namespace :vhost do
            desc <<-DESC
              Creates and symlinks an Nginx virtualhost entry.

              By default, this task uses a template called vhost.conf.erb found
              either in the :template_dir or /config/deploy folders.
            DESC
            task :setup, :except => { :no_release => true } do
              location = fetch(:template_dir, "config/deploy") + '/vhost.conf.erb'
              server_conf_path = fetch(:server_vhost_path, "/etc/nginx/sites-enabled")
              host = File.basename(deploy_to)

              if File.file?(location)
                template = File.read(location)
                config = ERB.new(template, nil , '-')
                run "mkdir -p #{shared_path}/config"
                dest = "#{shared_path}/config/#{host}.conf"
                put config.result(binding), dest
                run "ln -nfs #{dest} #{server_conf_path}"
              else
                puts "Skipping! Could not find a suitable template."
              end
            end
          end

          #
          # database.yml cap tasks
          #
          namespace :db do
            desc <<-DESC
              Creates a database.yml file in the apps shared path.
            DESC
            task :setup, :except => { :no_release => true } do

              require 'digest/sha1'
              app = appize(application, fetch(:stage))
              database = fetch(:db_database, app)
              username = fetch(:db_username, app)
              password = Capistrano::CLI.ui.ask("DB password for #{database} (empty for default): ")
              password = password.empty? ? Digest::SHA1.hexdigest(database) : password

              default_template = <<-EOF
      base: &base
        encoding: utf8
        adapter: postgresql
        pool: <%= fetch(:db_pool, 5) %>
        host: <%= fetch(:db_host, 'localhost') %>
      <%= fetch(:stage) %>:
        database: <%= database %>
        username: <%= username %>
        password: <%= password %>
        <<: *base
              EOF

              location = fetch(:template_dir, "config/deploy") + '/database.yml.erb'
              template = File.file?(location) ? File.read(location) : default_template
              config = ERB.new(template, nil , '-')

              run "mkdir -p #{shared_path}/config"
              put config.result(binding), "#{shared_path}/config/database.yml"
            end

            #
            # Updates the symlink for database.yml file to the just deployed release.
            #
            task :symlink, :except => { :no_release => true } do
              path_to_appl_database_yml = "#{release_path}/config/database.yml"
              path_to_conf_database_yml = "#{shared_path}/config/database.yml"

              run <<-END
                set -x;
                if [ -e #{path_to_conf_database_yml} ]; then
                  ln -nfs #{path_to_conf_database_yml} #{path_to_appl_database_yml}
                else
                  echo "Symlink not possible, database.yml not found.";
                fi;
              END
            end
          end

          after "deploy:finalize_update", "kyan:db:symlink"
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  CapistranoKyan::CapistranoIntegration.load_into(Capistrano::Configuration.instance)
else
  abort "Capinstrano-kyan requires Capistrano 2"
end
