#!/bin/bash
domain=$1
if [ -z "${domain}" ]; then
	echo ""
	echo "Usage: crx_dump_dns_domain.sh <domain>"
	echo ""
	exit 1
fi
passwd=$( grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | sed 's/de.cranix.dao.User.Register.Password=//' )
samba-tool dns query 127.0.0.1 ${domain} @ ALL -U register%${passwd} | sed -r 's/^\s+//'

