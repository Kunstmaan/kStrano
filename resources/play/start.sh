#!/bin/bash

if [ -z "$PLAY_ENV" ]; then
	PLAY_ENV="prod"
fi

START_PARAMETERS="-Dpidfile.path=./pids/play.pid -Dconfig.resource=$PLAY_ENV.conf -Dlogger.resource=$PLAY_ENV-logger.xml"
if [ -f "newrelic/newrelic.jar" ]; then
	START_PARAMETERS="$START_PARAMETERS -javaagent:newrelic/newrelic.jar -Dnewrelic.bootstrap_classpath=true"
else
	echo "no newrelic.jar file found!"
fi

nohup bash -c "target/start $START_PARAMETERS $* &>> ./logs/$PLAY_ENV.log" &