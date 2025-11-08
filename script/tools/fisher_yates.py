#!/usr/bin/env python3
import sys, random, json

if len(sys.argv) != 3:
    print("usage: fisher_yates.py <hex-seed> <total-supply>", file=sys.stderr)
    sys.exit(1)

seed = int(sys.argv[1], 16)
n = int(sys.argv[2])
perm = list(range(n))
rng = random.Random(seed)
for i in range(n - 1, 0, -1):
    j = rng.randrange(i + 1)
    perm[i], perm[j] = perm[j], perm[i]

print(json.dumps({"seed": sys.argv[1], "total": n, "permutation": perm}, separators=(',', ':')))
