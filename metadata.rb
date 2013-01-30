maintainer       "Ryan J. Geyer"
maintainer_email "me@ryangeyer.com"
license          "All rights reserved"
description      "Installs/Configures gitolite"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

depends "rightscale"
depends "git"
depends "perl"

recipe "gitolite::default", "Installs the gitolite binaries and sets up a single instance"

attribute "gitolite/home",
  :display_name => "Gitolite Instance Home Directory",
  :description => "The full path to the home directory for Gitolite",
  :default => "/mnt/storage/gitolite",
  :recipes => ["gitolite::default"]

attribute "gitolite/ssh_key",
  :display_name => "Gitolite Private Key",
  :description => "Private RSA (or DSA) key material to be used when initializing the gitolite repository/home. Set to ignore for a new key to be automatically generated.",
  :required => false,
  :recipes => ["gitolite::default"]