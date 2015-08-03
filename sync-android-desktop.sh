#!/bin/bash
# this script imports pictures from my phone to desktop and deletes them on the phone.
# it also syncronizes a music directory into the phone and viceversa
# if using the android ssh server app, the -r argument is the IP of the phone
# if not, a jmtpfs mount (USB) will be attempted 
# TODO add SMS sync
# TODO add ecryptfs

while getopts "p:r:d:m:Uh" OPT; do
    case ${OPT} in
	p)
	    PORT=${OPTARG}
	    ;;
	r)
	    REMOTE=${OPTARG}
	    ;;
	m)
	    SSHFS_MOUNTP=${OPTARG}
	    ;;
	d)
	    LOCALDEST=${OPTARG}
	    ;;
	U)
	    NO_UMOUNT=true
	    ;;
	j)
	    JMTPFS_MOUNTP=${OPTARG}
	    ;;
	h)
	    less ${0}
	    exit 0
	esac
done
    
LOCALDEST=${LOCALDEST:-"${HOME}/pictures/phone"}

REMOTE=${REMOTE}


SDCARD=""
MOUNT_TOP=""
SSH_MOUNT=false
if test -z ${REMOTE}; then
    JMTPFS_MOUNTP=${JMTPFS_MOUNTP:-"${HOME}/mnt/jmtp-mount-phone"}
    JMTPFS_TOP="${JMTPFS_MOUNTP}/Internal storage"
    if ! test -d "${JMTPFS_TOP}"; then
	[ -d "${JMTPFS_MOUNTP}" ] || mkdir -p "${JMTPFS_MOUNTP}"
	umount "${JMTPFS_MOUNTP}"
	if ! jmtpfs "${JMTPFS_MOUNTP}"; then
	    echo "no -r REMOTE option provided nor ${JMTPFS_MOUNTP} mounted" && exit ${LINENO}
	    exit ${LINENO}
	fi
    fi
    SDCARD="${JMTPFS_TOP}"
    MOUNT_TOP="${JMTPFS_TOP}"
else
    # TODO mount ecryptfs and umount after sync
    SSHFS_MOUNTP=${SSHFS_MOUNTP:-"${HOME}/mnt/phonemount"}
    PORT=${PORT:-"60043"}
    AUSER=${AUSER:-"root"}

    SSH_MOUNT=true
    mount | grep "${REMOTE}" || \
	sshfs -p ${PORT} "${AUSER}@${REMOTE}:" "${SSHFS_MOUNTP}" || exit ${LINENO}
    SDCARD="${SSHFS_MOUNTP}/sdcard"
    MOUNT_TOP="${MOUNT_TOP}"
fi

[ -d "${LOCALDEST}" ] || mkdir -p "${LOCALDEST}"

# trailing slash is important
for picture_loc in \
    "${SDCARD}/DCIM/" \
	"${MOUNT_TOP}/storage/emulated/0/DCIM/" \
	"${SDCARD}/Photaf/";
do
    if test -d "${picture_loc}"; then
	echo "copying from ${picture_loc}"
	rsync -arv --remove-source-files "${picture_loc}" "${LOCALDEST}" || exit ${LINENO}
    fi
    # find ${picture_loc} -type f -iregex '.*\(jpg\|mp4\)'  | xargs rm 
done

MUSIC_LOCAL="${HOME}/Music/"
MUSIC_PHONE="${SDCARD}/Music/"


rsync -rv "${MUSIC_LOCAL}" "${MUSIC_PHONE}"
rsync -rv "${MUSIC_PHONE}" "${MUSIC_LOCAL}" 

if [ -z ${NO_UMOUNT} ]; then
    if test ${SSH_MOUNT} = true; then
	sudo umount "${SSHFS_MOUNTP}" || echo "Not sshfs umounted"
    else
	sudo umount "${JMTPFS_MOUNTP}" || echo "Not jmtpfs umounted"
    fi
fi
