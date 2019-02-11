#!/usr/bin/env python2

import time
from urllib import urlopen


def wait_for(predicate, timeout=180):
    amount_slept = 0
    while not predicate():
        time.sleep(0.5)
        amount_slept += 0.5
        if amount_slept >= timeout:
            raise TimeoutError('Timeout waiting for ' + predicate.__name__)


def is_up():
    try:
        print(urlopen('http://localhost:4200'))
        return True
    except Exception:
        return False


if __name__ == "__main__":
    wait_for(is_up)
