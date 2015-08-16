xdr
=============
[![Build Status](https://travis-ci.org/todayman/xdr.svg?branch=master)](https://travis-ci.org/todayman/xdr)

This is an implementation of serialization and deserialization to the eXternal
Data Representation as described in RFC 4506.  I do not plan on implementing
the specification grammar.

License is AGPLv3.

Put values into an output range with "xdr.put(value)".
Get them out with xdr.get!type().
