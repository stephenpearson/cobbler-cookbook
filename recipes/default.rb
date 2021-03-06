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

package "libvirt-bin"
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
  notifies :restart, "service[isc-dhcp-server]"
end

template "/etc/cobbler/pxe/pxedefault.template" do
  source "pxedefault.template.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :run, "execute[restart_cobbler]", :delayed
end

template "/var/lib/cobbler/kickstarts/ubuntu-server-default.preseed" do
  source "ubuntu-server-default.preseed.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :run, "execute[restart_cobbler]", :delayed
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
  notifies :run, "execute[restart_cobbler]", :delayed
end

template "/etc/cobbler/settings" do
  source "settings.erb"
  owner "root"
  group "root"
  mode 0644
  variables({
    :server_address => server_address
  })
  notifies :run, "execute[restart_cobbler]", :immediately
end

execute "sync_cobbler" do
  command "cobbler sync"
  action :nothing
end

execute "restart_cobbler" do
  command "sleep 1; service cobbler stop; sleep 1; service cobbler start; sleep 10; "
  action :nothing
  notifies :run, "execute[sync_cobbler]", :immediately
end

service "cobbler" do
  action [ :enable, :start ]
  supports :status => true, :restart => false,
           :stop => true, :start => true, :reload => false
  notifies :run, "execute[sync_cobbler]", :immediately
end

service "isc-dhcp-server" do
  action [ :enable, :start ]
  supports :status => true, :restart => true, :reload => false
end
