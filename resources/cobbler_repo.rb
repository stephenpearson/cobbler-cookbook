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

resource_name :cobbler_repo

property :instance_name, String, name_property: true
property :apt_components, kind_of: Array, default: []
property :apt_dists, kind_of: Array, default: []
property :arch, kind_of: String, default: ""
property :breed, kind_of: String, default: ""
property :mirror, kind_of: String, default: ""
property :keep_updated, kind_of: [TrueClass, FalseClass], default: false
property :local_mirror, kind_of: [TrueClass, FalseClass], default: false
property :owners, kind_of: Array, default: ['admin']
property :priority, kind_of: Fixnum, default: 99

def get_repo_list
  repo_list_cmd = Mixlib::ShellOut.new("cobbler repo list")
  repo_list_cmd.run_command
  raise if repo_list_cmd.exitstatus != 0
  repo_list_cmd.stdout.split(/\n/).map(&:strip)
end

def get_repo_details(name)
  repos = get_repo_list
  if repos.include?(name)
    cmd = "cobbler repo report --name=#{name}"
    result = Mixlib::ShellOut.new(cmd).run_command
    raise "#{cmd} return non-zero status" if result.exitstatus != 0
    result = result.stdout.split(/\n/).map {|x| x.split(/ :/).map(&:strip)}
    Hash[result.map{|i| [i[0], i[1]] }]
  else
    nil
  end
end

def conv_str_to_list(str)
  str.delete("[]' ").split(/,/)
end

load_current_value do
  details = get_repo_details(instance_name)
  if details
    instance_name details["Name"]
    breed details["Breed"]
    if details["Breed"] == "apt"
      apt_components conv_str_to_list(details["Apt Components (apt only)"])
      apt_dists conv_str_to_list(details["Apt Dist Names (apt only)"])
    end
    arch details["Arch"]
    mirror details["Mirror"]
    local_mirror details["Mirror locally"] == "True"
    keep_updated details["Keep Updated"] == "True"
    owners conv_str_to_list(details["Owners"])
    priority details["Priority"].to_i
  end
end

action :create do
  converge_if_changed do
    execute "create_repo" do
      repos = get_repo_list
      if repos.include?(instance_name)
        cmd = "edit"
      else
        cmd = "add"
      end

      command "cobbler repo #{cmd} --name \"#{instance_name}\" " +
              "--apt-components=\"#{apt_components.join(" ")}\" " +
              "--apt-dists=\"#{apt_dists.join(" ")}\" " +
              "--arch=\"#{arch}\" " +
              "--breed=\"#{breed}\" " +
              "--mirror=\"#{mirror}\" " +
              "--mirror-locally=\"#{local_mirror.to_s}\" " +
              "--keep-updated=\"#{keep_updated.to_s}\" " +
              "--owners=\"#{owners}\" " +
              "--priority=#{priority.to_s}"
    end
  end
end
