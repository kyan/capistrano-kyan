# Capistrano Kyan

Capistrano plugin that includes a collection of tasks we find useful here at Kyan.

## Usage

### Prerequisites

We assume you are using multi-stage environments.

### Setup

Add the library to your `Gemfile`:

```ruby
group :development do
  gem 'capistrano-kyan'
end
```

Update your config/deploy.rb. Here's an example one:

```ruby
require 'capistrano-kyan'
require 'capistrano/ext/multistage'

set :stages, %w(production staging)
set :default_stage, "staging"
set :application, "ournewserver.co.uk"

set :user, "deploy"
set :use_sudo, false

ssh_options[:forward_agent] = true
default_run_options[:pty] = true

set :scm, :git
set :repository, "git@github.com:kyan/#{application}.git"
set :deploy_via, :remote_cache

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "ln -nfs #{shared_path}/config/application.yml #{release_path}/config/application.yml"
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

# these are the capistrano-kyan bits
after "deploy:setup",           "kyan:vhost:setup"
after "deploy:finalize_update", "kyan:db:symlink"
after "deploy:create_symlink",  "nginx:reload"
```

Add your vhost files:

```
#
# /config/vhosts/staging.vhost.conf.erb
#

server {
  listen 80;

  server_name staging.ournewserver.co.uk;
  root /var/www/staging.ournewserver.co.uk/current/public;
  passenger_enabled on;
  rails_env staging;
  client_max_body_size 4M;

  # serve static content directly
  location ~* \.(ico|jpg|gif|png|swf|html)$ {
    if (-f $request_filename) {
      expires max;
      break;
    }
  }
}
```

and

```
#
# /config/vhosts/production.vhost.conf.erb
#

server {
  listen 80;

  server_name ournewserver.co.uk;
  root /var/www/ournewserver.co.uk/current/public;
  passenger_enabled on;
  rails_env staging;
  client_max_body_size 4M;

  # serve static content directly
  location ~* \.(ico|jpg|gif|png|swf|html)$ {
    if (-f $request_filename) {
      expires max;
      break;
    }
  }
}
```

Now you need to update your multi-stage files to include these:

```
#
# config/deploy/staging.rb
#

server 'ournewserver.co.uk', :app, :web, :db, :primary => true
set :branch, "staging"
set :rails_env, 'staging'
set :deploy_to, "/var/www/staging.#{application}"
set :vhost_tmpl_name, "staging.vhost.conf.erb"
```

```
#
# config/deploy/production.rb
#

server 'ournewserver.co.uk', :app, :web, :db, :primary => true
set :branch, "staging"
set :rails_env, 'staging'
set :deploy_to, "/var/www/staging.#{application}"
set :vhost_tmpl_name, "production.vhost.conf.erb"
```

## Deploying

This will create the directory structure.


```
$ cap deploy:setup
```

Then you can test each individual task:

```
cap kyan:vhost:setup
```

## Configuration

You can modify any of the following options in your `deploy.rb` config.

- `vhost_env` - Set vhost environment. Default to `rails_env` variable.
- `vhost_tmpl_path` - Set vhost template path. Default to `config/deploy`.
- `vhost_tmpl_name` - Set vhost template name. Default to `vhost.conf.erb`.
- `vhost_server_path` - Set vhost server path. Default to `/etc/nginx/sites-enabled`.

## Available Tasks

To get a list of all capistrano tasks, run `cap -T`:

```
cap kyan:vhost:setup            # Creates and symlinks an Nginx virtualhost entry.
```

## License

See LICENSE file for details.