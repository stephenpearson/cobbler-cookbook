unless Vagrant.has_plugin?("vagrant-proxyconf")
  raise "vagrant-proxyconf plugin missing"
end

unless Vagrant.has_plugin?("vagrant-triggers")
  raise "vagrant-triggers plugin missing"
end

Vagrant.configure(2) do |config|
  # Allows busser gem and deps to be fetched as required
  PROXY="http://proxy.bbn.hp.com:8080"
  config.proxy.http     = PROXY
  config.proxy.https    = PROXY
  config.proxy.no_proxy = "localhost,127.0.0.1"
  config.trigger.after :up do
    run_remote "printf 'Acquire::http::Proxy \"#{PROXY}\";\n" +
               "Acquire::https::Proxy \"#{PROXY}\";\n' " +
               "> /etc/apt/apt.conf; apt-get update"
  end
end
