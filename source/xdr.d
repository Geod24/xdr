/*
 *  XDR - A D language implementation of the External Data Representation
 *  Copyright (C) 2015 Paul O'Neil
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Affero General Public License as
 *  published by the Free Software Foundation, either version 3 of the
 *  License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Affero General Public License for more details.
 *
 *  You should have received a copy of the GNU Affero General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

//! Provides an implementation of RFC 4506.
module xdr;

import std.bitmanip;
import std.range;
import std.traits;

class Serializer(Output) if (isOutputRange!(Output, ubyte))
{
    private:
    Output output;

    public:
    this(Output o)
    {
        output = o;
    }

    void put(T)(T val) if (T.sizeof % 4 == 0 && isIntegral!T)
    {
        std.range.put(output, nativeToBigEndian(val)[]);
    }

    void put(T: bool)(bool val)
    {
        if (val)
        {
            this.put!int(1);
        }
        else
        {
            this.put!int(0);
        }
    }

    void put(ulong len)(in ubyte[len] data) if (len % 4 == 0)
    {
        std.range.put(output, data[]);
    }

    void put(ulong len)(in ubyte[len] data) if (len % 4 != 0)
    {
        std.range.put(output, data[]);
        enum padding = 4 - (len % 4);
        std.range.put(output, [0, 0, 0][0 .. padding]);
    }

    void put(T: ubyte[])(in ubyte[] data)
    in {
        assert(data.length <= uint.max);
    }
    body {
        this.put!uint(data.length);
        std.rage.put(output, data);
        enum padding = 4 - (data.length % 4);
        std.range.put(output, [0, 0, 0][0 .. padding]);
    }

    void put(Array)(in Array data) if (isStaticArray!Array)
    {
        foreach (const ref elem; data)
        {
            this.put(data);
        }
    }

    void put(Array)(in Array data) if (isDynamicArray!Array)
    {
        this.put!uint(data.length);
        foreach (const ref elem; data)
        {
            this.put(data);
        }
    }
}

unittest
{
    Serializer!(ubyte[]) serializer;

    assert(__traits(compiles, serializer.put!char(2)) == false);
    assert(__traits(compiles, serializer.put!dchar(2)) == false);
    assert(__traits(compiles, serializer.put!wchar(2)) == false);

    assert(__traits(compiles, serializer.put!byte(2)) == false);
    assert(__traits(compiles, serializer.put!ubyte(2)) == false);
    assert(__traits(compiles, serializer.put!short(2)) == false);
    assert(__traits(compiles, serializer.put!ushort(2)) == false);

    assert(__traits(compiles, serializer.put!int(2)) == true);
    assert(__traits(compiles, serializer.put!uint(2)) == true);
    assert(__traits(compiles, serializer.put!long(2)) == true);
    assert(__traits(compiles, serializer.put!ulong(2)) == true);

    assert(__traits(compiles, serializer.put!bool(true)) == true);
}

unittest
{
    ubyte[] outBuffer = new ubyte[4];
    auto serializer = new Serializer!(ubyte[])(outBuffer);

    serializer.put!int(4);
    assert(outBuffer == [0, 0, 0, 4]);
}
