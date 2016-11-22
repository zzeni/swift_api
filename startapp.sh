#!/bin/sh

bundle exec thin -s 2 -C config.yml -R config.ru start
