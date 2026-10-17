#!/bin/bash

#DUPLICITY PASSPHRASE VARIABLE FOR ENCRYPTION
export PASSPHRASE="YOUR_DUPLICITY_PASSPHRASE_HERE"

#PASSPHRASE for 7ZIP encryption of DB dump
PASSPHRASE_ZIP="YOUR_7ZIP_PASSPHRASE_HERE"

export DUPLICITY_CMD=/usr/local/bin/duplicity

# WordPress source is independent of root's HOME.
WORDPRESS_BACKUP_SOURCE=/home/pmpanya/domains/watmarpjan.org
