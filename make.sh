#!/bin/bash

cd ..
base=$(pwd)

for resource in "sefthy-wrt-config" "sefthy-wrt-gui" "sefthy-wrt-monitor" "sefthy-wrt-wh" "sefthy-wrt-velch"; do
  cd $base/$resource
  zip -r $base/$resource.zip ./ -x '*.git*' -x '*.DS_Store' -x '*README.md'
done

for resource in "sefthy-wrt-config" "sefthy-wrt-gui" "sefthy-wrt-monitor" "sefthy-wrt-wh" "sefthy-wrt-velch"; do
  cd $base
  unzip $resource.zip -d ./build/sefthy/files
done
