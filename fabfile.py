# coding:utf-8
import os
import re

from fabric.api import env, run, local, cd, lcd, sudo, hide
from fabric.contrib.project import rsync_project as rsync
from fabric.utils import abort, puts

env.provision_dir = '/var/provision'
env.runtime = 'development'

env.colorize_errors = True
env.remote_interrupt = True
env.use_ssh_config = True
env.forward_agent = True
env.chef_url = ''.join([
    'https://packages.chef.io/files/stable/chef',
    '/13.3.42/ubuntu/16.04/chef_13.3.42-1_amd64.deb'
])

env.ssh_opts = ''
if env.disable_known_hosts is True:
    env.ssh_opts = ' '.join([
        '-o UserKnownHostsFile=/dev/null',
        '-o StrictHostKeyChecking=no'
    ])


def provision():
    local_directory = os.path.join(
        os.path.dirname(env.real_fabfile), 'provision'
    )
    if os.path.exists(local_directory + '/.local/chef.deb') is False:
        local('mkdir -p ' + local_directory + '/.local')

        with lcd(local_directory + '/.local'):
            local('curl -fL ' + env.chef_url + ' -o chef.deb')

    with hide('running'):
        sudo('mkdir -p ' + env.provision_dir)
        sudo('chown -R ' + env.user + ': ' + env.provision_dir)
        rsync(
            default_opts='-a',
            ssh_opts=env.ssh_opts,
            delete=True, exclude='nodes', local_dir=local_directory + '/',
            remote_dir=env.provision_dir + '/')

    # chef clientをインストール
    with cd(env.provision_dir + '/.local'):
        # chefがインストールされているか確認
        if run('dpkg -l chef', quiet=True).failed:
            sudo('dpkg -i chef.deb')

    # chefのレシピをサーバに実行
    with cd(env.provision_dir):
        recipe = 'recipe[app]'
        sudo('chef-client -z -c client.rb -E %s -o %s' % (env.runtime, recipe))
