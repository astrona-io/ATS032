"""Write a made-up vulnerability feed for the versions this cluster runs.

Usage: python3 feed.py kubelet=1.35.0 etcd=3.6.6 coredns=1.13.1 busybox=1.37.0

Each component gets two records drawn from three cases: affected
(introduced <= running < fixed), already fixed (fixed == running) and not yet
introduced (introduced > running). At least two records are affected and at
least two are not. The output is a plain-text table on standard output.
"""
import random
import sys


def text(version):
    return '.'.join(str(part) for part in version)


def record(case, running):
    major, minor, patch = running
    if case == 'affected':
        return (major, minor, max(0, patch - random.randint(0, patch))), (major, minor, patch + random.randint(1, 3))
    if case == 'fixed':
        return (major, max(0, minor - 1), 0), running
    return (major, minor, patch + 1), (major, minor, patch + random.randint(2, 4))


def main():
    running = {}
    for argument in sys.argv[1:]:
        name, version = argument.split('=', 1)
        running[name] = tuple(int(part) for part in version.split('.')[:3])
    while True:
        cases = [random.choice(['affected', 'fixed', 'later']) for _ in range(2 * len(running))]
        if cases.count('affected') >= 2 and len(cases) - cases.count('affected') >= 2:
            break
    severities = ['Low', 'Medium', 'High', 'Critical']
    identifiers = random.sample(range(1000, 9999), len(cases))
    rows = []
    for index, case in enumerate(cases):
        component = list(running)[index // 2]
        introduced, fixed = record(case, running[component])
        rows.append(('ADV-2026-%04d' % identifiers[index], component, text(introduced), text(fixed), random.choice(severities)))
    random.shuffle(rows)
    print('%-14s %-10s %-11s %-9s %s' % ('ID', 'COMPONENT', 'INTRODUCED', 'FIXED', 'SEVERITY'))
    for row in rows:
        print('%-14s %-10s %-11s %-9s %s' % row)


main()
