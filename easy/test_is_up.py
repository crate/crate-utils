#!/usr/bin/env python2

import time
from urllib import urlopen


def wait_for(predicate, timeout=300):
    amount_slept = 0
    sleep_interval = 0.5
    while not predicate():
        time.sleep(sleep_interval)
        amount_slept += sleep_interval
        if amount_slept >= timeout:
            raise SystemExit('Timeout waiting for ' + predicate.__name__)


def is_up():
    try:
        print(urlopen('http://localhost:4200'))
        return True
    except Exception:
        return False


if __name__ == "__main__":
    wait_for(is_up)
