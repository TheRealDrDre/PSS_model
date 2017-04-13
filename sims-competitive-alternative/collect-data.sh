#!/bin/bash

if [ -f final.txt ]; then
    rm final.txt
fi

if [ -f header ]; then
    rm header
fi

if [ -f final ]; then
    rm header
fi

for i in *.txt; do 
    if [ ! -f header ]; then
	head -1 $i > header
    fi
    echo -n "Collecting $i... "
    cat $i >> final 
    echo "Done"
done

cat header > final.txt
rm header
grep -v "Avoid" final >> final.txt
rm final
