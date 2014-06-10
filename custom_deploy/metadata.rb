name        "custom_deploy"
description "Deploy applications"
maintainer  "Lockside Software"
license     "Apache 2.0"
version     "1.0.0"

depends "deploy"
depends "nginx"
depends "ssh_users"
depends "opsworks_agent_monit"
depends "thin"

recipe "custom_deploy::rails", "Deploy a Rails application"
recipe "custom_deploy::rails-undeploy", "Remove a Rails application"