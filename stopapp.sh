#!/bin/sh

for x in *.pid; do
  kill `cat $x`;
done

