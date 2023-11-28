#!/bin/bash
STATUS=$(curl --silent http://localhost:4922/ping)
if [[ $STATUS == "pong" ]]; then
  echo "OK"
  exit 0
else
  echo "KO"
  exit 1
fi