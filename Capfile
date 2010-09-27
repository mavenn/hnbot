load 'deploy' if respond_to?(:namespace) # cap2 differentiator

default_run_options[:pty] = true

set :domain, "nyx.memamsa.com"
set :application, "watchbots"
set :user, "app"

set :scm, :git
set :deploy_via, :remote_cache
set :deploy_to, "/home/#{user}/#{application}"
set :repository,  "git@track.memamsa.net:watchbots.git"
set :branch, "master"
set :git_enable_submodules, 1
set :scm_verbose, true
set :use_sudo, false

server domain, :app, :web, :db

after "deploy:symlink", "deploy:whenever"

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
  
  desc "Update the crontab file"
  task :whenever, :roles => :db do
    vars = {:environment => "production", :path => "#{current_path}", 
      :cron_log => "#{shared_path}/log/cron.log"
    }
    varstr = vars.keys.map {|x| "#{x}=#{vars[x]}"}.join('&')
    run "whenever  -f #{current_path}/config/schedule.rb --set '#{varstr}' --update-crontab #{application}"  
  end
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

end
