# rubocop:disable Metrics/BlockLength, Style/IndentHeredoc

# sshd
service 'sshd' do
  action [:enable]
  supports start: true, status: true, restart: true, reload: true
end

file '/etc/ssh/sshd_config' do
  owner 'root'
  group 'root'
  mode 0o644
  content <<-"EOS"
# Package generated configuration file
# See the sshd_config(5) manpage for details

# What ports, IPs and protocols we listen for
Port 22
# Use these options to restrict which interfaces/protocols sshd will bind to
#ListenAddress ::
#ListenAddress 0.0.0.0
Protocol 2
# HostKeys for protocol version 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_dsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
#Privilege Separation is turned on for security
UsePrivilegeSeparation yes

# Lifetime and size of ephemeral version 1 server key
KeyRegenerationInterval 3600
ServerKeyBits 1024

# Logging
SyslogFacility AUTH
LogLevel INFO

# Authentication:
LoginGraceTime 120
PermitRootLogin no
StrictModes yes

RSAAuthentication yes
PubkeyAuthentication yes
#AuthorizedKeysFile	%h/.ssh/authorized_keys

# Don't read the user's ~/.rhosts and ~/.shosts files
IgnoreRhosts yes
# For this to work you will also need host keys in /etc/ssh_known_hosts
RhostsRSAAuthentication no
# similar for protocol version 2
HostbasedAuthentication no
# Uncomment if you don't trust ~/.ssh/known_hosts for RhostsRSAAuthentication
#IgnoreUserKnownHosts yes

# To enable empty passwords, change to yes (NOT RECOMMENDED)
PermitEmptyPasswords no

# Change to yes to enable challenge-response passwords (beware issues with
# some PAM modules and threads)
ChallengeResponseAuthentication no

# Change to no to disable tunnelled clear text passwords
#PasswordAuthentication yes

# Kerberos options
#KerberosAuthentication no
#KerberosGetAFSToken no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes

X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
#UseLogin no

#MaxStartups 10:30:60
#Banner /etc/issue.net

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

Subsystem sftp /usr/lib/openssh/sftp-server

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the ChallengeResponseAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via ChallengeResponseAuthentication may bypass
# the setting of "PermitRootLogin without-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and ChallengeResponseAuthentication to 'no'.
UsePAM yes
  EOS
  notifies :restart, 'service[sshd]'
end

# iptables
# https://help.ubuntu.com/community/IptablesHowTo
execute 'iptables' do
  user 'root'
  group 'root'
  environment(
    'PATH' => '/sbin:/usr/sbin:/bin:/usr/bin'
  )
  command '/tmp/iptables.sh'
  action :nothing
end

file '/etc/network/if-pre-up.d/iptablesload' do
  user 'root'
  group 'root'
  mode 0o500
  content <<-'EOF'
#!/bin/sh
iptables-restore < /etc/iptables.rules
exit 0
  EOF
end

file '/etc/network/if-post-down.d/iptablessave' do
  user 'root'
  group 'root'
  mode 0o500
  content <<-'EOF'
#!/bin/sh
iptables-save -c > /etc/iptables.rules
if [ -f /etc/iptables.downrules ]; then
  iptables-restore < /etc/iptables.downrules
fi
exit 0
  EOF
end

file '/tmp/iptables.sh' do
  user 'root'
  group 'root'
  mode 0o500
  content <<-'EOF'
#!/bin/bash

set -exu -o pipefail

PATH=/sbin:/usr/sbin:/bin:/usr/bin

SSH=22
HTTP=80
HTTPS=443

iptables -F # init table
iptables -X # delete chain
iptables -Z # clear packet / binary counter
iptables -P INPUT   ACCEPT
iptables -P OUTPUT  ACCEPT
iptables -P FORWARD ACCEPT

iptables -P INPUT   DROP # all drop
iptables -P OUTPUT  ACCEPT
iptables -P FORWARD DROP

# done session
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# local
iptables -A INPUT -s 127.0.0.1 -d 127.0.0.1 -j ACCEPT
iptables -A OUTPUT -s 127.0.0.1 -d 127.0.0.1 -j ACCEPT

# ping
iptables -A INPUT -p icmp -j ACCEPT
# ssh
iptables -A INPUT -p tcp --dport $SSH -j ACCEPT
iptables -A INPUT -p tcp --dport $HTTP -j ACCEPT
iptables -A INPUT -p tcp --dport $HTTPS -j ACCEPT

# dos attack
iptables -A INPUT -f -j LOG --log-prefix 'fragment_packet:'
iptables -A INPUT -f -j DROP

# drop bloadcast and multicast
iptables -A INPUT -d 192.168.1.255   -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 192.168.1.255   -j DROP
iptables -A INPUT -d 255.255.255.255 -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 255.255.255.255 -j DROP
iptables -A INPUT -d 224.0.0.1       -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 224.0.0.1       -j DROP

iptables-save -c > /etc/iptables.rules

exit 0
exit 1
  EOF
  notifies :run, 'execute[iptables]', :immediately
end
