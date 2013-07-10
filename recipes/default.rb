#
# Cookbook Name:: gitolite
# Recipe:: default
#
# Copyright 2013, Ryan J. Geyer
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

rightscale_marker :begin

gitolite_install = ::File.join(node["gitolite"]["install_dir"], "install")
ssh_dir = ::File.join(node["gitolite"]["home"], ".ssh")
tmp_private_key = ::File.join(Chef::Config[:file_cache_path], "id_rsa")
tmp_public_key = ::File.join(Chef::Config[:file_cache_path], "id_rsa.pub")
private_key = ::File.join(ssh_dir, "id_rsa")
public_key = ::File.join(ssh_dir, "id_rsa.pub")
gitolite_rc = ::File.join(node["gitolite"]["home"], ".gitolite.rc")

repositories_path = ::File.join(node["gitolite"]["home"], "repositories")

home_dir_parent = node["gitolite"]["home"].gsub(::File.basename(node["gitolite"]["home"], ""), "")

# Hardcode the git base_dir which git::server uses
node["git"]["server"]["base_path"] = repositories_path
node["git"]["server"]["export_all"] = "false"

case node["platform_family"]
  when "debian"
    su_param = "--command"
  when "rhel"
    su_param = "--session-command"
end

include_recipe "git"
# git::server is included as well, but at the end of this recipe so that
# all of the directories and configs and everything is in place before it runs
include_recipe "perl"

package "perl-Time-HiRes" if node["platform_family"] == "rhel"

git node["gitolite"]["install_dir"] do
  repository "https://github.com/sitaramc/gitolite.git"
  reference "master"
  action :sync
end

execute "Install gitolite binary" do
  command "#{gitolite_install} -ln #{node["gitolite"]["bin_dir"]}"
end

directory home_dir_parent do
  recursive true
end

group node["gitolite"]["gid"] do
  action :create
end

user node["gitolite"]["uid"] do
  comment "Gitolite repository"
  gid node["gitolite"]["gid"]
  home node["gitolite"]["home"]
end

#directory ssh_dir do
#  group node["gitolite"]["gid"]
#  owner node["gitolite"]["uid"]
#  mode 00700
#  recursive true
#  action :create
#end

if node["gitolite"]["ssh_key"]
  file tmp_public_key do
    content node["gitolite"]["ssh_key"]
    mode 00600
    group node["gitolite"]["gid"]
    owner node["gitolite"]["uid"]
    backup false
    action :create
  end
else
  execute "Create a net-new private and public SSH key" do
    command "ssh-keygen -q -t rsa -N \"\" -f #{tmp_private_key}"
    creates tmp_private_key
  end
end

execute "Initialize a fresh gitolite instance (if one does not already exist)" do
  command <<-EOF
  su #{su_param}="gitolite setup -pk #{tmp_public_key}" #{node["gitolite"]["uid"]}
EOF
  creates ::File.join(repositories_path, "gitolite-admin.git")
end

template gitolite_rc do
  source "gitolite.rc.erb"
  backup false
  owner node["gitolite"]["uid"]
  group node["gitolite"]["gid"]
  mode 00755
end

ruby_block "Copy the private key to gitolites home (if one was generated dynamically)" do
  block do
    if ::File.exist?(tmp_private_key)
      FileUtils.cp(tmp_private_key, private_key)
    end
  end
end

include_recipe "git::server"

bash "Enforce proper permissions for (#{repositories_path})" do
  code <<-EOF
  chown -R #{node["gitolite"]["uid"]}:#{node["gitolite"]["gid"]} #{node["gitolite"]["home"]}
  chmod 0775 -R #{repositories_path}
EOF
end

rightscale_marker :end