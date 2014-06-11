node[:deploy].each do |application, deploy|
  deploy = node[:deploy][application]

  template "#{deploy[:deploy_to]}/shared/config/secrets.yml" do
    source "secrets.yml.erb"
    cookbook 'custom_rails'
    mode "0660"
    group deploy[:group]
    owner deploy[:user]
    variables(:secrets => deploy[:secrets], :environment => deploy[:rails_env])

    notifies :run, "execute[restart Rails app #{application}]"

    #only_if do
    #  deploy[:secrets].present? && File.directory?("#{deploy[:deploy_to]}/shared/config/")
    #end
  end
end