# Capistrano Kyan

Capistrano plugin that includes a collection of tasks we find useful here at Kyan.

## Usage

### Setup

Add the library to your `Gemfile`:

```ruby
group :development do
  gem 'capistrano-kyan', :git => "https://github.com/kyan/capistrano-kyan.git", :require => false
end
```

And load it into your deployment script `config/deploy.rb`:

```ruby
require 'capistrano-kyan'
```

Add kyan vhost task hook:

```ruby
after "deploy:setup", "kyan:vhost:setup"
```

Add kyan db task hook:

```ruby
after "deploy:setup", "kyan:db:setup"
```

### Test

First, make sure you're running the latest release:

```
cap deploy:setup
```

Then you can test each individual task:

```
cap kyan:db:setup
cap kyan:vhost:setup
```

## Configuration

You can modify any of the following options in your `deploy.rb` config.

- `vhost_env` - Set vhost environment. Default to `rails_env` variable.
- `vhost_tmpl_path` - Set vhost template path. Default to `config/deploy`.
- `vhost_tmpl_name` - Set vhost template name. Default to `vhost.conf.erb`.
- `vhost_server_path` - Set vhost server path. Default to `/etc/nginx/sites-enabled`.
- `vhost_server_name` - Set vhost server name. Default to `File.basename(deploy_to)`.

I'm assuming you are using capistrano multistage.

## Available Tasks

To get a list of all capistrano tasks, run `cap -T`:

```
cap kyan:db:setup               # Creates a database.yml file in the apps shared path.
cap kyan:vhost:setup            # Creates and symlinks an Nginx virtualhost entry.
```

## License

See LICENSE file for details.