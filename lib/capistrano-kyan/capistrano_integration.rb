require 'capistrano'
require 'capistrano/version'

module CapistranoKyan
  class CapistranoIntegration
    TASKS = [
      'deploy:seed',
      'deploy:add_env',
      'kyan:db:setup',
      'kyan:vhost:setup',
      'kyan:vhost:show',
      'nginx:start',
      'nginx:stop',
      'nginx:restart',
      'nginx:reload',
      'foreman:export',
      'foreman:start',
      'foreman:stop',
      'foreman:restart'
    ]

    def self.load_into(capistrano_config)
      capistrano_config.load do
        before(CapistranoIntegration::TASKS) do
          _cset(:app_env)             { (fetch(:rails_env) rescue 'staging') }
          _cset(:vhost_env)           { fetch(:app_env) }
          _cset(:vhost_tmpl_path)     { 'config/vhosts' }
          _cset(:vhost_tmpl_name)     { 'vhost.conf.erb' }
          _cset(:vhost_server_path)   { '/etc/nginx/sites-enabled' }
          _cset(:vhost_server_name)   { File.basename(deploy_to) rescue fetch(:app_env) }
        end

        def appize(app, prefix = 'staging')
          "#{app.gsub('.','_')}_#{prefix}"
        end

        def tmpl_server_location
          run "mkdir -p #{shared_path}/config"
          File.join(shared_path, 'config', "#{File.basename(deploy_to)}.conf")
        end

        def symlink(target, link)
          run "ln -nfs #{target} #{link}"
        end

        def parse_template(template)
          ERB.new(File.read(template), nil , '-').result(binding)
        end

        def build_vhost(path, name)
          [
            File.join(path, name),
            File.join(File.dirname(__FILE__),'../../templates/vhost.conf.erb')
          ].each do |template|
            if File.file? template
              return parse_template(template)
            end
          end
        end

        namespace :deploy do
          desc "Load the database with seed data"
          task :seed do
            run "cd #{current_path}; bundle exec rake db:seed RAILS_ENV=#{app_env}"
          end

          task :add_env do
            put "RAILS_ENV=#{app_env}", "#{release_path}/.env"
          end
        end

        after "deploy:finalize_update", "deploy:add_env"

        namespace :nginx do
          task :start, :roles => :app, :except => { :no_release => true } do
            run "sudo /etc/init.d/nginx start"
          end

          task :stop, :roles => :app, :except => { :no_release => true } do
            run "sudo /etc/init.d/nginx stop"
          end

          task :restart, :roles => :app, :except => { :no_release => true } do
            run "sudo /etc/init.d/nginx restart"
          end

          task :reload, :roles => :app, :except => { :no_release => true } do
            run "sudo /etc/init.d/nginx reload"
          end
        end

        namespace :foreman do
          desc "Export the Procfile to Ubuntu's upstart scripts"
          task :export, :roles => :app do
            run "cd #{release_path} && sudo foreman export upstart /etc/init -a #{application} -u #{user} -l #{shared_path}/log"
          end
          desc "Start the application services"
          task :start, :roles => :app do
            sudo "start #{application}"
          end

          desc "Stop the application services"
          task :stop, :roles => :app do
            sudo "stop #{application}"
          end

          desc "Restart the application services"
          task :restart, :roles => :app do
            run "sudo start #{application} || sudo restart #{application}"
          end
        end

        namespace :kyan do
          #
          # vhost cap tasks
          #
          namespace :vhost do
            desc <<-DESC
              Creates and symlinks an Nginx virtualhost entry.

              By default, this task uses a builtin template which you
              see the output with rake kyan:vhost:show. If you need to
              customise this, you can create your own erb template and
              update the :vhost_tmpl_path and :vhost_tmpl_name variables.
            DESC
            task :setup, :except => { :no_release => true } do
              if tmpl = build_vhost(vhost_tmpl_path, vhost_tmpl_name)
                put tmpl, tmpl_server_location
                symlink(tmpl_server_location, vhost_server_path)
              else
                puts "Could not find a suitable template."
              end
            end

            desc "Displays the vhost that will be uploaded to server"
            task :show, :except => { :no_release => true } do
              puts build_vhost(vhost_tmpl_path, vhost_tmpl_name)
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

              run "ln -nfs #{path_to_conf_database_yml} #{path_to_appl_database_yml}"
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
