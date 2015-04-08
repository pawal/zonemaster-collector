#!/bin/sh

# using curl:
# curl -s http://www.internic.net/domain/root.zone
# or as plain text: http://data.iana.org/TLD/tlds-alpha-by-domain.txt

dig . axfr @xfr.lax.dns.icann.org | awk '$4=="NS" { print $1}' | sort -u
