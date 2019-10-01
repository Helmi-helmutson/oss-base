#!/bin/bash
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

case $ACTION in
	update)
		/usr/sbin/oss_update.sh
	;;
	reboot)
		/usr/bin/systemctl reboot
	;;
	shutdown)
		/usr/bin/systemctl poweroff
	;;
esac
