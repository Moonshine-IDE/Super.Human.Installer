#!/bin/bash

## Simple wrapper for vagrant up to write to a log as well as the console

LOG_FILE=vagrant_ssh.log

vagrant ssh 2>&1 | tee $LOG_FILE

echo "Log written to:  $LOG_FILE"
