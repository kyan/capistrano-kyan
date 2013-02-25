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
          _cset(:app_env)             { (fetch(:rails_env) rescue 'staging') }
          _cset(:vhost_env)           { fetch(:app_env) }
          _cset(:vhost_tmpl_path)     { 'config/deploy' }
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

        #
        # vhost cap tasks
        #
        namespace :kyan do
          namespace :vhost do
            desc <<-DESC
              Creates and symlinks an Nginx virtualhost entry.

              By default, this task uses a builtin template and should
              work fine for most cases. If you to customise this,
              you can run rake kyan:vhost:clone. Or you can create
              own vhost.conf.erb, either in the :template_dir or
              the /config/deploy folder.
            DESC
            task :setup, :except => { :no_release => true } do
              locations = [
                File.join(File.dirname(__FILE__),'../../templates'),
                vhost_tmpl_path
              ]

              locations.each do |location|
                template = File.join(location, vhost_tmpl_name)

                if File.file? template
                  put parse_template(template), tmpl_server_location
                  symlink(tmpl_server_location, vhost_server_path)
                  break
                else
                  puts "Skipping! Could not find a suitable template."
                end
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
