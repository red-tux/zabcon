#!/bin/bash

# this script sets up zabcon so that it may be used directly from the svn checkout
# if you want to start from an empty state (no existing checkout), uncomment the following 3 lines;
# in that case, run this script from the directory in which "zabcon" and "api" directories reside

#svn co -N http://svn.red-tux.net/trunk/ruby .
#svn up api zabcon
#cd zabcon

ln -s ../api/zbxapi.rb zbxapi.rb
ln -s ../api/zbxapi zbxapi
#ln -s ../api/api_classes api_classes

#No longer needed, zabcon uses a search path of "."
#cd libs
#ln -s ../api/libs/api_exceptions.rb api_exceptions.rb
#ln -s ../api/libs/exceptions.rb exceptions.rb
#ln -s ../api/libs/zdebug.rb zdebug.rb

#cd -
