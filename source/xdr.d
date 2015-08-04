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

    void put(T)(T val)
        if (T.sizeof % 4 == 0 && (isIntegral!T || isFloatingPoint!T))
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
    // The existence of this method seems to solve const/overload problems
    void put(bool val)
    {
        put!bool(val);
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

    void put(Array)(in Array data) if (isStaticArray!Array)
    {
        foreach (const ref elem; data)
        {
            this.put(elem);
        }
    }

    void put(Array)(in Array data)
        if (isDynamicArray!Array && !is(Array == ubyte[]) && !is(Array == string))
    in {
        assert(data.length <= uint.max);
    }
    body {
        this.put!uint(cast(uint)data.length);
        foreach (const ref elem; data)
        {
            this.put(elem);
        }
    }

    void put(T: ubyte[])(in T data)
    in {
        assert(data.length <= uint.max);
    }
    body {
        this.put!uint(cast(uint)data.length);
        std.range.put(output, data);
        if (data.length % 4 > 0)
        {
            immutable pad_length = 4 - (data.length % 4);
            ubyte[] padding = [0, 0, 0];
            std.range.put(output, padding[0 .. pad_length]);
        }
    }

    // FIXME combine with ubyte[]
    void put(T: string)(in T data)
    in {
        assert(data.length <= uint.max);
    }
    body {
        this.put!uint(cast(uint)data.length);
        std.range.put(output, data);
        if (data.length % 4 > 0)
        {
            immutable pad_length = 4 - (data.length % 4);
            ubyte[] padding = [0, 0, 0];
            std.range.put(output, padding[0 .. pad_length]);
        }
    }

    void put(T)(in T data)
        if (isAggregateType!T && !hasIndirections!T)
    {
        foreach (elem; data.tupleof)
        {
            put(elem);
        }
    }
}

Serializer!O makeSerializer(O)(O o)
{
    return new Serializer!O(o);
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

    assert(__traits(compiles, serializer.put!float(1.0)) == true);
    assert(__traits(compiles, serializer.put!double(1.0)) == true);

    assert(__traits(compiles, serializer.put!(ubyte[])([])) == true);
    assert(__traits(compiles, serializer.put!(string)("")) == true);

    assert(__traits(compiles, serializer.put!(short[])([])) == false);
    assert(__traits(compiles, serializer.put!(ushort[])([])) == false);

    assert(__traits(compiles, serializer.put!(short[2])([1, 2])) == false);

    assert(__traits(compiles, serializer.put!(int[2])([1, 2])) == true);
    assert(__traits(compiles, serializer.put!(uint[2])([1, 2])) == true);
    assert(__traits(compiles, serializer.put!(long[2])([1, 2])) == true);
    assert(__traits(compiles, serializer.put!(ulong[2])([1, 2])) == true);
    // Commented out pending std.bitmanip.EndianSwap stuff
    // From std.bitmanip.d:2210
    // private union EndianSwapper(T)
    //     if(canSwapEndianness!T)
    // {
    //     Unqual!T value;
    //     ubyte[T.sizeof] array;
    //
    //     static if(is(FloatingPointTypeOf!T == float))
    //         uint  intValue;
    //     else static if(is(FloatingPointTypeOf!T == double))
    //         ulong intValue;
    //
    // }
    // The static ifs fail because FloatingPointTypeOf!(const(float)) == const(float), not float
    // assert(__traits(compiles, serializer.put!(float[2])([1, 2])) == true);
    // assert(__traits(compiles, serializer.put!(double[2])([1, 2])) == true);
    assert(__traits(compiles, serializer.put!(bool[2])([true, false])) == true);
}

unittest
{
    ubyte[] outBuffer = new ubyte[4];
    auto serializer = makeSerializer(outBuffer);

    serializer.put!int(4);
    assert(outBuffer == [0, 0, 0, 4]);
}

unittest
{
    ubyte[] outBuffer = new ubyte[4];
    auto serializer = makeSerializer(outBuffer);

    serializer.put!bool(true);
    assert(outBuffer == [0, 0, 0, 1]);
}

unittest
{
    ubyte[] outBuffer = new ubyte[8];
    auto serializer = makeSerializer(outBuffer);

    serializer.put!long(4);
    assert(outBuffer == [0, 0, 0, 0, 0, 0, 0, 4]);
}

unittest
{
    ubyte[] outBuffer = new ubyte[8];
    auto serializer = makeSerializer(outBuffer);

    ubyte[] data = [1, 2, 3, 4];
    serializer.put(data);
    assert(outBuffer == [0, 0, 0, 4, 1, 2, 3, 4]);
}
unittest
{
    ubyte[] outBuffer = new ubyte[8];
    auto serializer = makeSerializer(outBuffer);

    ubyte[] data = [1, 2, 3];
    serializer.put(data);
    assert(outBuffer == [0, 0, 0, 3, 1, 2, 3, 0]);
}

unittest
{
    ubyte[] outBuffer = new ubyte[12];
    auto serializer = makeSerializer(outBuffer);

    string data = "hello";
    serializer.put(data);
    assert(outBuffer == [0, 0, 0, 5, 'h', 'e', 'l', 'l', 'o', 0, 0, 0]);
}

unittest
{
    ubyte[] outBuffer = new ubyte[8];
    auto serializer = makeSerializer(outBuffer);

    int[2] data = [1, 2];
    serializer.put(data);
    assert(outBuffer == [0, 0, 0, 1, 0, 0, 0, 2]);
}

unittest
{
    ubyte[] outBuffer = new ubyte[8];
    auto serializer = makeSerializer(outBuffer);

    struct AB
    {
        int a;
        int b;
    }

    AB ab = {1, 2};
    serializer.put(ab);
    assert(outBuffer == [0, 0, 0, 1, 0, 0, 0, 2]);
}
