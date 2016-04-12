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

resource_name :cobbler_profile

property :instance_name, String, name_property: true
property :owners, kind_of: Array, default: ['admin']
property :distro, kind_of: String, default: ""
property :enable_gpxe, kind_of: [TrueClass, FalseClass], default: false
property :enable_menu, kind_of: [TrueClass, FalseClass], default: true
property :kickstart, kind_of: String, default: ""
property :kickstart_metadata, kind_of: Hash, default: {}
property :name_servers, kind_of: Array, default: []
property :name_servers_search, kind_of: Array, default: []
property :kopts, kind_of: Hash, default: {}
property :kopts_post_install, kind_of: Hash, default: {}
property :proxy, kind_of: String, default: ""
property :repos, kind_of: Array, default: []
property :comment, kind_of: String, default: ""
property :tftp_boot_files, kind_of: Hash, default: {}
property :dhcp_tag, kind_of: String, default: "default"
property :fetchable_files, kind_of: Hash, default: {}
property :mgmt_classes, kind_of: Array, default: []
property :template_files, kind_of: Hash, default: {}
property :virt_auto_boot, kind_of: [TrueClass, FalseClass], default: false
property :virt_bridge, kind_of: String, default: ""
property :virt_cpus, kind_of: Fixnum, default: 1
property :virt_disk_driver, kind_of: String, default: "raw"
property :virt_file_size, kind_of: Fixnum, default: 5
property :virt_path, kind_of: String, default: ""
property :virt_ram, kind_of: Fixnum, default: 512
property :virt_type, kind_of: String, default: "kvm"

def get_profile_list
  profile_list_cmd = Mixlib::ShellOut.new("cobbler profile list")
  profile_list_cmd.run_command
  raise if profile_list_cmd.exitstatus != 0
  profile_list_cmd.stdout.split(/\n/).map(&:strip)
end

def get_profile_details(name)
  profiles = get_profile_list
  if profiles.include?(name)
    cmd = "cobbler profile report --name=#{name}"
    result = Mixlib::ShellOut.new(cmd).run_command
    raise "#{cmd} return non-zero status" if result.exitstatus != 0
    result = result.stdout.split(/\n/).map {|x| x.split(/ :/).map(&:strip)}
    Hash[result.map{|i| [i[0], i[1]] }]
  else
    nil
  end
end

def parse_str(str)
  YAML.load(str)
end

def hash_to_opts(h)
  h.keys.sort.map {|k| "#{k}=#{h[k]}"}.join(" ")
end

load_current_value do
  details = get_profile_details(instance_name)
  if details
    instance_name details["Name"]
    owners parse_str(details["Owners"])
    distro details["Distribution"]
    enable_gpxe details["Enable gPXE?"] == "True"
    enable_menu details["Enable PXE Menu?"] == "True"
    kickstart details["Kickstart"]
    kickstart_metadata parse_str(details["Kickstart Metadata"])
    name_servers parse_str(details["Name Servers"])
    name_servers_search parse_str(details["Name Servers Search Path"])
    kopts parse_str(details["Kernel Options"])
    kopts_post_install parse_str(details["Kernel Options (Post Install)"])
    proxy details["Proxy"]
    repos parse_str(details["Repos"])
    comment details["Comment"]
    tftp_boot_files parse_str(details["TFTP Boot Files"])
    dhcp_tag details["DHCP Tag"]
    fetchable_files parse_str(details["Fetchable Files"])
    mgmt_classes parse_str(details["Management Classes"])
    template_files parse_str(details["Template Files"])
    virt_auto_boot details["Virt Auto Boot"] == "1"
    virt_bridge details["Virt Bridge"]
    virt_cpus details["Virt CPUs"].to_i
    virt_disk_driver details["Virt Disk Driver Type"]
    virt_file_size details["Virt File Size(GB)"].to_i
    virt_path details["Virt Path"]
    virt_ram details["Virt RAM (MB)"].to_i
    virt_type details["Virt Type"]
  end
end

action :create do
  converge_if_changed do
    execute "create_profile" do
      profiles = get_profile_list
      if profiles.include?(instance_name)
        cmd = "edit"
      else
        cmd = "add"
      end

      command "cobbler profile #{cmd} --name \"#{instance_name}\" " +
              "--owners=\"#{owners.join(" ")}\" " +
              "--distro=\"#{distro}\" " +
              "--enable-gpxe=\"#{enable_gpxe.to_s}\" " +
              "--enable-menu=\"#{enable_menu.to_s}\" " +
              "--kickstart=\"#{kickstart}\" " +
              "--ksmeta=\"#{hash_to_opts(kickstart_metadata)}\" " +
              "--kopts=\"#{hash_to_opts(kopts)}\" " +
              "--kopts-post=\"#{hash_to_opts(kopts_post_install)}\" " +
              "--proxy=\"#{proxy}\" " +
              "--repos=\"#{repos.join(" ")}\" " +
              "--comment=\"#{comment}\" " +
              "--virt-auto-boot=\"#{virt_auto_boot ? '1' : '0' }\" " +
              "--virt-cpus=\"#{virt_cpus.to_s}\" " +
              "--virt-file-size=\"#{virt_file_size.to_s}\" " +
              "--virt-disk-driver=\"#{virt_disk_driver}\" " +
              "--virt-ram=\"#{virt_ram.to_s}\" " +
              "--virt-type=\"#{virt_type}\" " +
              "--virt-path=\"#{virt_path}\" " +
              "--virt-bridge=\"#{virt_bridge}\" " +
              "--dhcp-tag=\"#{dhcp_tag}\" " +
              "--name-servers=\"#{name_servers.join(" ")}\" " +
              "--name-servers-search=\"#{name_servers_search.join(" ")}\" " +
              "--mgmt-classes=\"#{mgmt_classes.join(" ")}\" " +
              "--boot-files=\"#{hash_to_opts(tftp_boot_files)}\" " +
              "--fetchable-files=\"#{hash_to_opts(fetchable_files)}\" " +
              "--template-files=\"#{hash_to_opts(template_files)}\""
    end
  end
end

action :delete do
  profiles = get_profile_list
  if profiles.include?(instance_name)
    execute "remove_profile" do
      command "cobbler profile remove --name \"#{instance_name}\""
    end
  end
end
