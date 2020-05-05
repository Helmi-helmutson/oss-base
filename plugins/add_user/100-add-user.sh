#!/bin/bash
#
# Copyright (c) 2018 Peter Varkoly Nürnberg, Germany.  All rights reserved.
#

if [ ! -e /etc/sysconfig/schoolserver ]; then
   echo "ERROR This ist not an CRANIX."
   exit 1
fi

. /etc/sysconfig/schoolserver

if [ -z "${CRANIX_HOME_BASE}" ]; then
   echo "ERROR CRANIX_HOME_BASE must be defined."
   exit 2
fi

if [ ! -d "${CRANIX_HOME_BASE}" ]; then
   echo "ERROR CRANIX_HOME_BASE must be a directory and must exist."
   exit 3
fi

abort() {
        TASK="add_user-$( uuidgen -t )"
	mkdir -p /var/adm/cranix/opentasks/
        echo "uid: $uid" >> /var/adm/cranix/opentasks/$TASK
        echo "password: $password" >> /var/adm/cranix/opentasks/$TASK
        echo "mpassword: $mpassword" >> /var/adm/cranix/opentasks/$TASK
        echo "surname: $surname" >> /var/adm/cranix/opentasks/$TASK
        echo "givenname: $givenname" >> /var/adm/cranix/opentasks/$TASK
        echo "role: $role" >> /var/adm/cranix/opentasks/$TASK
        echo "fsquota: $fsquota" >> /var/adm/cranix/opentasks/$TASK
        echo "msquota: $msquota" >> /var/adm/cranix/opentasks/$TASK
        exit 1
}

surname=''
givenname=''
role=''
uid=''
password=''
mpassword='no'
fsquota=0
msquota=0
groups=""


while read a
do
  b=${a/:*/}
  if [ "$a" != "${b}:" ]; then
     c=${a/$b: /}
  else
     c=""
  fi
  case $b in
    surname)
      surname="${c}"
    ;;
    givenname)
      givenname="${c}"
    ;;
    uid)
      uid="${c}"
    ;;
    role)
      role="${c}"
    ;;
    password)
      password="${c}"
    ;;
    mpassword)
      mpassword="${c}"
    ;;
    fsquota)
      fsquota="${c}"
    ;;
    msquota)
      msquota="${c}"
      msquota=$((msquota*1024))
    ;;
  esac
done

skel="/etc/skel"

winprofile="\\\\${CRANIX_NETBIOSNAME}\\profiles\\$uid"
winhome="\\\\${CRANIX_NETBIOSNAME}\\$uid"

if [ $CRANIX_SORT_HOMES = "yes" ]; then
        unixhome=${CRANIX_HOME_BASE}/$role/$uid
else
        unixhome=${CRANIX_HOME_BASE}/$uid
fi

if [ $mpassword != "no" ]; then
   ADDPARAM=" --must-change-at-next-login"
fi

if [ "$role" = "workstations"  -o "$role" = "guests" ]; then
    samba-tool domain passwordsettings set --complexity=off
fi

uidNumber=$( /usr/share/cranix/tools/get_next_id )

samba-tool user create "$uid" "$password" \
				--userou="OU=${role}" \
				--use-username-as-cn \
				--username="$uid" \
				--uid="$uid" \
				--password="$password" \
				--surname="$surname" \
				--given-name="$givenname" \
				--home-drive="Z:" \
				--profile-path="$winprofile" \
				--script-path="$uid.bat" \
				--home-directory="$winhome" \
				--nis-domain="${CRANIX_WORKGROUP}" \
				--unix-home="$unixhome" \
				--login-shell=/bin/bash \
				--uid-number=$uidNumber \
				--gid-number=100 \
				--mail-address="${uid}@${CRANIX_DOMAIN}" \
				$ADDPARAM

if [ $? != 0 ]; then
   abort
fi
if [ "${CRANIX_CHECK_PASSWORD_QUALITY}" = "yes" ]; then
   samba-tool domain passwordsettings set --complexity=on
fi

#create home diredtory copy template user homedirectory and set permission
mkdir -p $unixhome
/usr/sbin/crx_copy_template_home.sh $uid
if [ "$CRANIX_TEACHER_OBSERV_HOME" = "yes" -a "$role" = "students" ]; then
	chown -R $uidNumber:TEACHERS "$unixhome"
	chmod 0770 "$unixhome"
else
	chown -R $uidNumber:100 "$unixhome"
	chmod 0700 "$unixhome"
fi
#Workaround
if [ $CRANIX_SORT_HOMES = "yes" ]; then
        ln -s $unixhome ${CRANIX_HOME_BASE}/${CRANIX_WORKGROUP}/$uid
fi


#Samba has to recognize the ne user
sleep 3

#add user to groups
samba-tool group addmembers "$role" "$uid"

#Workstation users password should not expire
if [ "$role" = "workstations" ]; then
	tmpldif=$( mktemp /tmp/XXXXXXXX )
	/usr/sbin/crx_get_dn.sh $uid > $tmpldif
	echo "changetype: modify
add: userWorkstations
userWorkstations: ${CRANIX_NETBIOSNAME},$uid" >> $tmpldif
	ldbmodify  -H /var/lib/samba/private/sam.ldb $tmpldif
	samba-tool user setexpiry  --noexpiry $uid
	rm -f $tmpldif
	#pdbedit -u $uid -c "[X]"
fi

#Set default quota
if [ -z "$fsquota" ]; then
        fsquota=$CRANIX_FILE_QUOTA
        if [ $role = "teachers" ]; then
                fsquota=$CRANIX_FILE_TEACHER_QUOTA
        fi
fi

/usr/sbin/crx_set_quota.sh $uid $fsquota

#Set mailsystem quota
if [ "$role" != "workstations" -a "$role" != "guests" ]; then
	/usr/sbin/crx_set_mquota.pl $uid $msquota
fi

