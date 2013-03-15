default_run_options[:pty] = true

set :application, "huginn"
set :user, "deployer"
set :deploy_to, "/home/#{user}/apps/#{application}"
set :use_sudo, false
set :scm, :git
set :rails_env, 'production'
set :repository, "git@github.com:rswaminathan/huginn.git"
set :branch, "master"
set :deploy_via, :remote_cache
set :keep_releases, 5

set :bundle_without, [:development]
set :unicorn_pid, "#{shared_path}/pids/unicorn.pid"

server "173.255.244.162", :app, :delayed_job, :web, :db, :primary => true
#ssh_options[:forward_agent] = true

set :delayed_job_server_role, :delayed_job

set :sync_backups, 3

before 'deploy:restart', 'deploy:migrate'
after 'deploy', 'deploy:cleanup'

set :bundle_without, [:development, :test]


after "deploy:stop", "delayed_job:stop"
after "deploy:start", "delayed_job:start"
after "deploy:restart", "delayed_job:restart"

namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/unicorn_#{application} #{command}"
    end
  end

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.yml"), "#{shared_path}/config/database.yml"
    puts "Now edit the config files in #{shared_path}."
  end
  after "deploy:setup", "deploy:setup_config"

  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
end
#
# If you want to use command line options, for example to start multiple workers,
# define a Capistrano variable delayed_job_args:
#
#   set :delayed_job_args, "-n 2"

# If you want to use rvm on the server:
# set :rvm_ruby_string, '1.9.3-p286@huginn'
# set :rvm_type, :user
# before 'deploy', 'rvm:install_rvm'
# before 'deploy', 'rvm:install_ruby'
# require "rvm/capistrano"

# Load Capistrano additions
Dir[File.expand_path("../../lib/capistrano/*.rb", __FILE__)].each{|f| load f }

require "bundler/capistrano"
require "capistrano-unicorn"
require "delayed/recipes"
load 'deploy/assets'
