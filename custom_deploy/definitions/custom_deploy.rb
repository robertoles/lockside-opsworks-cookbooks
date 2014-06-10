define :custom_deploy do
  application = params[:app]
  deploy = params[:deploy_data]

  directory "#{deploy[:deploy_to]}" do
    group deploy[:group]
    owner deploy[:user]
    mode "0775"
    action :create
    recursive true
  end

  if deploy[:scm]
    ensure_scm_package_installed(deploy[:scm][:scm_type])

    prepare_git_checkouts(
      :user => deploy[:user],
      :group => deploy[:group],
      :home => deploy[:home],
      :ssh_key => deploy[:scm][:ssh_key]
    )
  end

  deploy = node[:deploy][application]

  directory "#{deploy[:deploy_to]}/shared/cached-copy" do
    recursive true
    action :delete
    only_if do
      deploy[:delete_cached_copy]
    end
  end

  ruby_block "change HOME to #{deploy[:home]} for source checkout" do
    block do
      ENV['HOME'] = "#{deploy[:home]}"
    end
  end

  # setup deployment & checkout
  if deploy[:scm] && deploy[:scm][:scm_type] != 'other'
    Chef::Log.debug("Checking out source code of application #{application} with type #{deploy[:application_type]}")
    deploy deploy[:deploy_to] do
      provider Chef::Provider::Deploy.const_get(deploy[:chef_provider])
      if deploy[:keep_releases]
        keep_releases deploy[:keep_releases]
      end
      repository deploy[:scm][:repository]
      user deploy[:user]
      group deploy[:group]
      revision deploy[:scm][:revision]
      migrate deploy[:migrate]
      migration_command deploy[:migrate_command]
      environment deploy[:environment].to_hash
      create_dirs_before_symlink( deploy[:create_dirs_before_symlink] )
      symlink_before_migrate( deploy[:symlink_before_migrate] )
      action deploy[:action]

      
      restart_command "sleep #{deploy[:sleep_before_restart]} && #{node[:opsworks][:rails_stack][:restart_command]}"
      

      scm_provider :git
      enable_submodules deploy[:enable_submodules]
      shallow_clone deploy[:shallow_clone]
      
      
      before_migrate do
        link_tempfiles_to_current_release

        if deploy[:auto_bundle_on_deploy]
          OpsWorks::RailsConfiguration.bundle(application, node[:deploy][application], release_path)
        end

        node.default[:deploy][application][:database][:adapter] = OpsWorks::RailsConfiguration.determine_database_adapter(
          application,
          node[:deploy][application],
          release_path,
          :force => node[:force_database_adapter_detection],
          :consult_gemfile => node[:deploy][application][:auto_bundle_on_deploy]
        )

        template "#{node[:deploy][application][:deploy_to]}/shared/config/database.yml" do
          cookbook "rails"
          source "database.yml.erb"
          mode "0660"
          owner node[:deploy][application][:user]
          group node[:deploy][application][:group]
          variables(
            :database => node[:deploy][application][:database],
            :environment => node[:deploy][application][:rails_env]
          )

          only_if do
            deploy[:database][:host].present?
          end
        end.run_action(:create)

        template "#{node[:deploy][application][:deploy_to]}/shared/config/secrets.yml" do
          cookbook "custom_rails"
          source "secrets.yml.erb"
          mode "0660"
          owner node[:deploy][application][:user]
          group node[:deploy][application][:group]
          variables(:secrets => deploy[:secrets], :environment => deploy[:rails_env])

          only_if do
            deploy[:database][:host].present?
          end
        end.run_action(:create)
        

        # run user provided callback file
        run_callback_from_file("#{release_path}/deploy/before_migrate.rb")
      end
    end
  end

  ruby_block "change HOME back to /root after source checkout" do
    block do
      ENV['HOME'] = "/root"
    end
  end

  if deploy[:application_type] == 'rails' && node[:opsworks][:instance][:layers].include?('rails-app')
    
    thin_web_app do
      application application
      deploy deploy
    end

  end

  template "/etc/logrotate.d/opsworks_app_#{application}" do
    backup false
    source "logrotate.erb"
    cookbook 'deploy'
    owner "root"
    group "root"
    mode 0644
    variables( :log_dirs => ["#{deploy[:deploy_to]}/shared/log" ] )
  end
end
