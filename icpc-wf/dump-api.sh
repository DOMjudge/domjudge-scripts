#!/bin/sh

contest=$1
where=$2
baseurl="https://domjudge/api/contests"

mkdir -p "$where"

for endpoint in judgement-types languages problems groups organizations teams state submissions judgements runs clarifications scoreboard; do
	http GET "$baseurl/$contest/$endpoint" | python -mjson.tool > "$where/${endpoint}.json"
done
endpoint=contest
http GET "$baseurl/$contest" | python -mjson.tool > "$where/${endpoint}.json"
endpoint=event-feed
http GET "$baseurl/$contest/${endpoint}?stream=0" > "$where/${endpoint}.json"
