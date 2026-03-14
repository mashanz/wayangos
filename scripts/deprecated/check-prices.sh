#!/bin/bash
curl -s 'https://api.dexscreener.com/latest/dex/tokens/0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b,0x940181a94A35A4569E4529A3CDfB74e38FD98631' | python3 -c "
import sys,json
d=json.load(sys.stdin)
for p in d.get('pairs',[])[:4]:
    print(p['baseToken']['symbol']+': \$'+str(p['priceUsd']))
"
