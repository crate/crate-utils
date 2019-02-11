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
        self.process = None

    def tearDown(self):
        if self.process:
            self.process.kill()
            self.process.communicate()
            self.process.wait()
        run(['vagrant', 'destroy', '--force'], cwd=self.dir)
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_try_on_ubuntu_18(self):
        bootstrap = (
            'apt-get update',
            'apt-get install -y default-jre-headless',
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
            'yum install -y java-11-openjdk',
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
