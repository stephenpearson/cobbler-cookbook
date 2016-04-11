#
# Cookbook Name:: cobbler
# Recipe:: default
#
# Copyright 2016, Stephen Pearson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package "cobbler"
package "bind9"
package "isc-dhcp-server"

# Get the network details from the provisioning interface
iface = node['cobbler']['provisioning_interface']
addrs = node['network']['interfaces'][iface]['addresses']
server_address = addrs.select do |a|
  addrs[a]['family'] == 'inet'
end.keys.first
server_ip = IPAddr.new(server_address)
netmask = addrs[server_address].netmask
network = server_ip.mask(netmask)
route = network.succ
ip_list = network.to_range.to_a
dhcp_start = ip_list[8]
dhcp_end = ip_list[ip_list.size / 2]

template "/etc/default/isc-dhcp-server" do
  source "isc-dhcp-server.erb"
  owner "root"
  group "root"
  mode 0644
  variables({
    :interface => iface
  })
end

template "/etc/cobbler/pxe/pxedefault.template" do
  source "pxedefault.template.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, "service[cobbler]", :delayed
end

template "/etc/cobbler/dhcp.template" do
  source "dhcp.template.erb"
  owner "root"
  group "root"
  mode 0644
  variables({
    :server_address => server_address,
    :netmask => netmask,
    :name_servers => node['cobbler']['name_servers'],
    :network => network.to_s,
    :route => route.to_s,
    :dhcp_start => dhcp_start,
    :dhcp_end => dhcp_end
  })
  notifies :restart, "service[cobbler]", :delayed
end

template "/etc/cobbler/settings" do
  source "settings.erb"
  owner "root"
  group "root"
  mode 0644
  variables({
    :server_address => server_address
  })
  notifies :restart, "service[cobbler]", :immediately
end

execute "sync_cobbler" do
  command "cobbler sync"
  action :nothing
end

service "cobbler" do
  action :enable
  enabled true
  running true
  restart_command "service cobbler stop; sleep 1" +
                  "service cobbler start; sleep 1"
  supports [ :stop, :start, :status ]
  notifies :run, "execute[sync_cobbler]", :immediately
end

service "isc-dhcp-server" do
  action :enable
  enabled true
  running true
  supports [ :stop, :start, :status ]
end

cobbler_repo "test123" do
  apt_components ['main', 'universe']
  apt_dists ['trusty', 'trusty-updates', 'trusty-security']
  arch "x86_64"
  breed "apt"
  mirror "http://gb.archive.ubuntu.com/ubuntu/"
  local_mirror false
end
