#!/bin/bash

# This script allows zabcon to be executed from SVN without the zbxapi
# being previously installed.  This script assumes that it is being called
# from within the zabcon directory inside the SVN repository.

if [[ "x$RUBYLIB" == "z" ]]; then
  export RUBYLIB="../api/"
else
  export RUBYLIB="../api/:$RUBYLIB"
fi

./zabcon.rb $*
