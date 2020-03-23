#!/usr/bin/env python3

from pathlib import Path
from subprocess import run
from unittest import TestCase
from urllib.request import urlopen
import urllib.error
import time
import os
import shutil
import tempfile


SOURCE_DIR = os.path.dirname(__file__)
CONTENTS = '''
Vagrant.configure('2') do |config|
    config.vm.box = "{box}"
    config.vm.define "{name}"
    config.vm.provision "shell", path: "bootstrap.sh"
    config.vm.synced_folder "{source_dir}", "/vagrant"

    config.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2
    end
end
'''


class TryTest(TestCase):

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())

    def tearDown(self):
        run(['vagrant', 'destroy', '--force'], cwd=self.dir)
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_try_on_ubuntu_18(self):
        bootstrap = (
            'apt-get update',
            'sudo -u vagrant /vagrant/try.sh &',
            'curl --retry-connrefused --retry 100 --retry-max-time 180 http://localhost:4200',
        )
        with open(self.dir / 'bootstrap.sh', 'w') as f:
            f.writelines((l + '\n' for l in bootstrap))
        with open(self.dir / 'Vagrantfile', 'w') as f:
            f.write(CONTENTS.format(
                source_dir=SOURCE_DIR,
                name='ubuntu',
                box='ubuntu/bionic64'))
        run(['vagrant', 'up'], cwd=self.dir, check=True)

    def test_try_on_centos7(self):
        bootstrap = (
            'yum update -y',
            'sudo -u vagrant /vagrant/try.sh &',
            # curl in centos7 doesn't have --retry-connrefused
            '/vagrant/test_is_up.py',
        )
        with open(self.dir / 'bootstrap.sh', 'w') as f:
            f.writelines((l + '\n' for l in bootstrap))
        with open(self.dir / 'Vagrantfile', 'w') as f:
            f.write(CONTENTS.format(
                source_dir=SOURCE_DIR,
                name='centos7',
                box='centos/7'))
        run(['vagrant', 'up'], cwd=self.dir, check=True)


class InstallTest(TestCase):

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())

    def tearDown(self):
        run(['vagrant', 'destroy', '--force'], cwd=self.dir)
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_install_on_ubuntu_18(self):
        bootstrap = (
            'apt-get update',
            'sudo -u vagrant /vagrant/install.sh &',
            'curl --retry-connrefused --retry 100 --retry-max-time 180 http://localhost:4200',
        )
        with open(self.dir / 'bootstrap.sh', 'w') as f:
            f.writelines((l + '\n' for l in bootstrap))
        with open(self.dir / 'Vagrantfile', 'w') as f:
            f.write(CONTENTS.format(
                source_dir=SOURCE_DIR,
                name='ubuntu18',
                box='ubuntu/bionic64'))
        run(['vagrant', 'up'], cwd=self.dir, check=True)

    def test_install_on_ubuntu_14(self):
        bootstrap = (
            'apt-get update',
            'sudo -u vagrant /vagrant/install.sh &',
            '/vagrant/test_is_up.py',
        )
        with open(self.dir / 'bootstrap.sh', 'w') as f:
            f.writelines((l + '\n' for l in bootstrap))
        with open(self.dir / 'Vagrantfile', 'w') as f:
            f.write(CONTENTS.format(
                source_dir=SOURCE_DIR,
                name='ubuntu14',
                box='ubuntu/trusty64'))
        run(['vagrant', 'up'], cwd=self.dir, check=True)
