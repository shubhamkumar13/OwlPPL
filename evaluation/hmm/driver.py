import time
import subprocess


def js():
    s = time.time()
    a = subprocess.check_output(['webppl', './hmm.js'])
    e = time.time()
    return a, e-s


a, t = js()
print(a, t)
