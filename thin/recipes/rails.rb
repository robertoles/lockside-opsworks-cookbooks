unless node[:opsworks][:skip_uninstall_of_other_rails_stack]
  include_recipe "apache2::uninstall"
end

include_recipe "nginx"
include_recipe "thin"

# setup Unicorn service per app
node[:deploy].each do |application, deploy|
  if deploy[:application_type] != 'rails'
    Chef::Log.debug("Skipping unicorn::rails application #{application} as it is not an Rails app")
    next
  end

  opsworks_deploy_user do
    deploy_data deploy
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  execute "thin service setup" do
    cwd "#{deploy[:deploy_to]}/current"
    command "thin config -C #{deploy[:deploy_to]}/shared/config/thin.yml -c #{deploy[:deploy_to]}/current --servers 3 -e production"
  end

  service "thin_#{application}" do
    start_command "#{deploy[:deploy_to]}/current/thin start -C #{deploy[:deploy_to]}/shared/config/thin.yml"
    stop_command "#{deploy[:deploy_to]}/current/thin stop -C #{deploy[:deploy_to]}/shared/config/thin.yml"
    restart_command "#{deploy[:deploy_to]}/current/thin restart -C #{deploy[:deploy_to]}/shared/config/thin.yml"
    action :nothing
  end
end
