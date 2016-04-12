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

resource_name :cobbler_import_iso

property :instance_name, String, name_property: true
property :url, kind_of: String, default: ""
property :sha256, kind_of: String, default: ""

ISO_ROOT = "/var/cobbler/iso"

action :create do
  iso_path = "#{ISO_ROOT}/#{instance_name}"
  mount_path = "/var/www/cobbler/ks_mirror/#{instance_name}"

  directory ISO_ROOT do
    owner "root"
    group "root"
    mode 0755
    recursive true
  end

  directory mount_path do
    owner "root"
    group "root"
    mode 0755
    recursive true
    not_if do
      ::Dir.exists?(mount_path)
    end
  end

  remote_file iso_path do
    checksum sha256
    source url
    owner "root"
    group "root"
    mode 0644
  end

  mount mount_path do
    action [ :mount, :enable ]
    options "loop"
    device iso_path
  end
end

action :delete do
  iso_path = "#{ISO_ROOT}/#{instance_name}"
  mount_path = "/var/www/cobbler/ks_mirror/#{instance_name}"

  mount mount_path do
    action [ :unmount, :disable ]
  end

  file iso_path do
    action :delete
  end

  directory mount_path do
    action :delete
  end
end
