#!/bin/bash

# load environment variables
source /etc/container_environment.sh

# default puppet master port is 8410
test -z "$PUPPETMASTER_TCP_PORT" && export PUPPETMASTER_TCP_PORT="8410"

# default SSL DNS names for certificate generation hostname,fqdn,puppet,puppet.domain
hostname="$(facter hostname)"
domain="$(facter domain)"
fqdn="$(facter fqdn)"

test -z "$PUPPETMASTER_DNS_NAMES" && \
    export PUPPETMASTER_DNS_NAMES="$hostname,$fqdn,puppet,puppet.$domain"

# if there's no certificate yet, generate it
if [ ! -f "/var/lib/puppet/ssl/certs/$hostname.pem" ]; then 
    puppet cert generate --dns_alt_names "$PUPPETMASTER_DNS_NAMES" $fqdn >/dev/null 2>&1
fi

# set no-daemonize and the master port
puppet_master_args="--no-daemonize --masterport $PUPPETMASTER_TCP_PORT"

# module path, manifest path, and environment path should all live in /data
puppet_master_args="$puppet_master_args --manifestdir /data/manifests/ --modulepath /data/modules/"

# environments should also live in /data
puppet_master_args="$puppet_master_args --environmentpath /data/environments/"

# a function to create nonexistet directories and chown them
function create_and_own () { 
    test -d $1 || mkdir -p $1
    chown -R $2:$2 $1
}

# we want /data to be owned by root
create_and_own /data root

# we want manifests, modules, and environments to be owned by puppet
create_and_own /data/manifests puppet
create_and_own /data/modules puppet
create_and_own /data/environments puppet

# only root can do important things in /data
chmod 7775 /data

# only the puppet user can read/write/execute things in here
chmod 7770 /data/manifests /data/modules /data/environments

# start the puppet master
exec /usr/bin/puppet master $puppet_master_args
