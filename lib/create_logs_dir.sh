#!/bin/bash

# Directory path
DIR=~/server_scripts_logs

# Check if the directory does not exist and create it
if [ ! -d "$DIR" ]; then
  mkdir -p "$DIR"
  echo "Directory $DIR created."
else
  echo "Directory $DIR already exists."
fi
