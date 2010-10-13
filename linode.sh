
#!/bin/bash
# 
# Installs MySQL, Ruby Enterprise edition, and Nginx with Passenger, Rails 2.3.9 along with Twitter, oauth2 gems. 
# It also adds REE to the system-wide $PATH
#
# <UDF name="ree_version" Label="Ruby Enterprise Edition Version" default="1.8.7-2010.01" example="1.8.7-2010.01" />
# <UDF name="install_prefix" Label="Install Prefix for REE and Passenger" default="/opt/local" example="/opt/local will install REE to /opt/local/ree" />
# <UDF name="rr_env" Label="Rails/Rack environment to run" default="production" />
# <udf name="gems_to_install1" label="Gems to install" manyOf="mysql,capistrano,twitter,json,oauth2" default="mysql,capistrano,twitter,json,oauth2" example="Each selected gem will be installed." />
# <udf name="gems_to_install2" label="More gems to install" default="rails -v 2.3.9,rack -v 1.0.1" example="Comma separated inputs to gem install. Example: rails,nifty-generators,formtastic,... Add the -v if you need a specific version." />

source <ssinclude StackScriptID=904> # Enable Universe

logfile="/root/log.txt"
rubyscript="/root/ruby_script_to_run.rb" 

# This script is generated and run after gem is installed to
# install the list of gems given by the stack script."

export logfile
export gems_to_install1="$GEMS_TO_INSTALL1"
export gems_to_install2="$GEMS_TO_INSTALL2"
# exported to be available in ruby_script_to_run.rb

system_update
echo "System Updated" >> $logfile
postfix_install_loopback_only
echo "postfix_install_loopback_only" >> $logfile
mysql_install "$DB_PASSWORD" && mysql_tune 40
echo "Mysql installed" >> $logfile
mysql_create_database "$DB_PASSWORD" "$DB_NAME"
mysql_create_user "$DB_PASSWORD" "$DB_USER" "$DB_USER_PASSWORD"
mysql_grant_user "$DB_PASSWORD" "$DB_USER" "$DB_NAME"



# Set up some necessary ENV variables
  # Should be set from UDF if run through Linode
  if [ ! -n "$REE_VERSION" ]; then
    REE_VERSION="1.8.7-2010.01"
  fi
  if [ ! -n "$INSTALL_PREFIX" ]; then
    INSTALL_PREFIX="/usr/local"
  fi
  if [ ! -n "$RR_ENV" ]; then
    RR_ENV="production"
  fi
  if [ ! -n "$TMPDIR" ]; then
    TMPDIR="/var/tmp"
  fi

  REE_NAME="ruby-enterprise-$REE_VERSION"
  REE_FILENAME="$REE_NAME.tar.gz"
  REE_DOWNLOAD="http://rubyforge.org/frs/download.php/68719/$REE_FILENAME"
  WORKING_DIR="$TMPDIR/flux-setup"

  mkdir -p "$WORKING_DIR"


# Set up Ruby Enterprise Edition
  # Dependencies
  apt-get -y install build-essential zlib1g-dev libssl-dev libreadline5-dev

  # Download
  cd       "$WORKING_DIR"
  wget     "$REE_DOWNLOAD" -O "$REE_FILENAME"
  tar xzf  "$REE_FILENAME"
  cd       "$REE_NAME"
  
  # Install
  ./installer --auto="$INSTALL_PREFIX/$REE_NAME"
  ln -s "$INSTALL_PREFIX/$REE_NAME" "$INSTALL_PREFIX/ree"

  # Add REE to the PATH
  PATH="$INSTALL_PREFIX/ree/bin:$PATH"

# Set up Nginx and Passenger
  passenger-install-nginx-module --auto --auto-download --prefix="$INSTALL_PREFIX/nginx"

  
echo "" >> $logfile
echo "Downloading Ruby Gems with wget http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz" >> $logfile
echo "" >> $logfile
wget http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz >> $logfile

echo ""
echo "tar output:"
tar xzvf rubygems-1.3.6.tgz  >> $logfile
rm rubygems-1.3.6.tgz

echo ""
echo "rubygems setup:"
cd rubygems-1.3.6
ruby setup.rb >> $logfile
cd /
rm -rf rubygems-1.3.6

echo ""
echo "gem update --system:"
gem update --system >> $logfile

# echo the ruby code to a file to be run
echo "
    ##### Ruby Code Starts Here #####

    gems_to_install1 = ENV['gems_to_install1']
    gems_to_install2 = ENV['gems_to_install2']
    
    puts gems_to_install1
    puts gems_to_install2
    
    gems_to_install1.split(',').each do |gem_name|
      \`gem install #{gem_name} >> $logfile\`
    end
    
    gems_to_install2.split(',').each do |gem_name|
      \`gem install #{gem_name} >> $logfile\`
    end

	 ##### Ruby Code Ends Here #####" >> $rubyscript
	 
	ruby $rubyscript >> $logfile

# Set up environment
# Global environment variables
  cat > /etc/environment << EOF
PATH="$PATH"
RAILS_ENV="$RR_ENV"
RACK_ENV="$RR_ENV"
EOF


# Clean up
  rm -rf "$WORKING_DIR"

restartServices
echo "StackScript Finished!" >> $logfile