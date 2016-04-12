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

resource_name :cobbler_distro

property :instance_name, String, name_property: true
property :arch, kind_of: String, default: ""
property :kernel, kind_of: String, default: ""
property :initrd, kind_of: String, default: ""
property :kopts, kind_of: Hash, default: {}
property :kopts_post_install, kind_of: Hash, default: {}
property :kickstart_metadata, kind_of: Hash, default: {}
property :breed, kind_of: String, default: ""
property :os_version, kind_of: String, default: ""
property :comment, kind_of: String, default: ""
property :mgmt_classes, kind_of: Array, default: []
property :tftp_boot_files, kind_of: Hash, default: {}
property :fetchable_files, kind_of: Hash, default: {}
property :template_files, kind_of: Hash, default: {}
property :owners, kind_of: Array, default: ['admin']

def get_distro_list
  distro_list_cmd = Mixlib::ShellOut.new("cobbler distro list")
  distro_list_cmd.run_command
  raise if distro_list_cmd.exitstatus != 0
  distro_list_cmd.stdout.split(/\n/).map(&:strip)
end

def get_distro_details(name)
  distros = get_distro_list
  if distros.include?(name)
    cmd = "cobbler distro report --name=#{name}"
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
  details = get_distro_details(instance_name)
  if details
    instance_name details["Name"]
    arch details["Architecture"]
    kernel details["Kernel"]
    initrd details["Initrd"]
    kopts parse_str(details["Kernel Options"])
    kopts_post_install parse_str(details["Kernel Options (Post Install)"])
    kickstart_metadata parse_str(details["Kickstart Metadata"])
    breed details["Breed"]
    os_version details["OS Version"]
    comment details["Comment"]
    mgmt_classes parse_str(details["Management Classes"])
    tftp_boot_files parse_str(details["TFTP Boot Files"])
    fetchable_files parse_str(details["Fetchable Files"])
    template_files parse_str(details["Template Files"])
    owners parse_str(details["Owners"])
  end
end

action :create do
  converge_if_changed do
    execute "create_distro" do
      distros = get_distro_list
      if distros.include?(instance_name)
        cmd = "edit"
      else
        cmd = "add"
      end

      command "cobbler distro #{cmd} --name \"#{instance_name}\" " +
              "--arch=\"#{arch}\" " +
              "--kernel=\"#{kernel}\" " +
              "--initrd=\"#{initrd}\" " +
              "--kopts=\"#{hash_to_opts(kopts)}\" " +
              "--kopts-post=\"#{hash_to_opts(kopts_post_install)}\" " +
              "--ksmeta=\"#{hash_to_opts(kickstart_metadata)}\" " +
              "--breed=\"#{breed}\" " +
              "--os-version=\"#{os_version}\" " +
              "--comment=\"#{comment}\" " +
              "--mgmt-classes=\"#{mgmt_classes.join(" ")}\" " +
              "--boot-files=\"#{hash_to_opts(tftp_boot_files)}\" " +
              "--fetchable-files=\"#{hash_to_opts(fetchable_files)}\" " +
              "--template-files=\"#{hash_to_opts(template_files)}\" " +
              "--owners=\"#{owners.join(" ")}\""
    end
  end
end

action :delete do
  distros = get_distro_list
  if distros.include?(instance_name)
    execute "remove_distro" do
      command "cobbler distro remove --name \"#{instance_name}\""
    end
  end
end
