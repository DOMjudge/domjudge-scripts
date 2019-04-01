#!/bin/bash

set -euo pipefail


for i in */problem.yaml; do
	dir=$(dirname $i)
	( cd $dir; rm ../${dir}.zip; zip -r ../${dir}.zip .timelimit * )
	echo
	echo "Press enter to continue upload ${dir}."
       	read
	http -f POST https://localhost/api/contests/test1/problems problem=${dir} zip[]@${dir}.zip
done
