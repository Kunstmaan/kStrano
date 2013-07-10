#!/bin/bash

pid=`cat ./pids/play.pid 2> /dev/null`

if [ "$pid" == "" ]; then
	echo '{{application_name}} is not running'; exit 0;
fi

echo "Stopping {{application_name}} ($pid) ..."

kill -SIGTERM $pid"