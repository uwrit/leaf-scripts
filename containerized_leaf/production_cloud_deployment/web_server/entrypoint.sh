#!/usr/bin/env bash
set -e
export LD_LIBRARY_PATH="/opt/shibboleth-sp/lib:${LD_LIBRARY_PATH}"

# start shibd (background)
/opt/shibboleth-sp/sbin/shibd -f -p /opt/shibboleth-sp/var/run/shibd.pid -w 30 &

# start Apache in foreground
exec httpd-foreground
