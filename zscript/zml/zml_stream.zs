/*

    What: Z-xtensible Markup Language File Stream Definition
    Who: Sarah Blackburn
    When: 19/02/22

*/


/*
    A StreamLine is an array of characters
    that make up each line of a file

*/
class StreamLine
{
    int Length,     // Total number of characters in the array
        TrueLine;   // This is the actual line number in the file - for error output

    // Each character is stored as a string in the array - be nice to have actual chars
    array<string> Chars;

    /*
        Works like any other Mid function,
        but works on the Chars array.
        Returns a string comprising the given length,
        starting from the given index.
    */
    string Mid(int at = 0, int len = 1)
    {
        string s = "";
        if (at >= 0 && len > 0 &&
            at < Length && at + len < Length)
        {
            for (int i = 0; i < len; i++)
                s.AppendFormat("%s", Chars[i + at]);
        }

        return s;
    }

    /*
        Returns the entire line as a single string
    */
    string FullLine()
    {
        string f = "";
        for (int i = 0; i < Length; i++)
            f.AppendFormat("%s", Chars[i]);
        return f;
    }

    /*
        Line constructor

        Generally, this system is set to remove whitespace,
        however if that isn't desired for some reason, set mode to true.
    */
    StreamLine Init(string Line, int TrueLine, bool mode = false)
    {
        // Put each character of the string into the array - normally remove whitespace
        for (int i = 0; i < Line.Length(); i++)
        {
            int a = Line.ByteAt(i);
            if (mode ? true : (a > 32 && a < 127))
            {
                string c = Line.Mid(i, 1);
                Chars.Push(c.MakeLower());
            }
        }

        self.Length = Chars.Size();
        self.TrueLine = TrueLine;

        if (self.Length > 0)
            return self;
        else
            return null;
    }
}


/*
    This is the actual "file stream" representation of the file.
    The string that is read

*/
class FileStream
{
    // The Stream member contains the textual information of each file
    array<StreamLine> Stream;
    // Lines() is a wrapper of Stream.Size(), generally used when wanting to know how many lines are in the stream
    int Lines() { return Stream.Size(); }

    int Line,           // Line represents which line of the file the reader is on
        Head,           // Head is ths character read head of the line
        LumpNumber,     // This is basically useless but interesting - this is the l value from Wads.ReadLump
        LumpHash,       // This value is calculated by hashing the contents of the lump and is used to eliminate duplicate reads
        StreamLength;   // This is the total number of characters in the entire stream.

    /*
        Returns the global index in the stream,
        which is the count of total characters
        read thus far.
    */
    int StreamIndex()
    {
        int si = 0;
        for (int i = 0; i < Line; i++)
            si += Stream[i].Length;
        return si + Head;
    }

    int LineLength() { return Stream[Line].Length; }

    /*
        https://bit.ly/3sqyUXj

        (Goes to StackOverflow)

        Its been a long while since I had a CS class
        that made me write my own hash function,
        so I just borrowed one from the link above.

        Kinda dirty, but it's used to create an ID hash
        for each file, to be checked during lump read,
        otherwise the reader makes duplicates for some
        odd reason.
    
    */
    static int GetLumpHash(string rl)
    {
        int a = 54059;
        int b = 76963;
        int c = 86969;
        int h = 37;
        for (int i = 0; i < rl.Length(); i++)
            h = (h * a) ^ (rl.ByteAt(i) * b);

        return h % c;
    }


    /*
        Returns the character on the given line at the given read index

    */
    string CharAt(int line, int head) { return head < LineLength() ? Stream[line].Chars[head] : ""; }

    /*
        Stream constructor
    
    */
    FileStream Init(string RawLump, int LumpNumber, bool mode = false)
    {
        self.Line = 0;
        self.Head = 0;
        self.LumpNumber = LumpNumber;
        self.LumpHash = FileStream.GetLumpHash(RawLump);

        // Break each line of the file into a StreamLine object
        string l = "";
        int tln = 1;    // This is the true line number, this is only for information during error output
        for (int i = 0; i < RawLump.Length(); i++)
        {
            string n = RawLump.Mid(i, 1);
            if (n != "\n" && n != "\0")
                l.AppendFormat("%s", n);
            else if (l.Length() > 0)
            {
                StreamLine sl = new("StreamLine").Init(l, tln++, mode);
                if (sl)
                    Stream.Push(sl);
                l = "";
            }
        }

        self.StreamLength = 0;
        for (int i = 0; i < Stream.Size(); i++)
            self.StreamLength += Stream[i].Length;

        /*console.printf(string.Format("File Stream contains %d lines.  Contents:", Lines()));
        for (int i = 0; i < Lines(); i++)
        {
            string e = "";
            for (int j = 0; j < Stream[i].Length; j++)
                e = string.Format("%s%s", e, CharAt(i, j));
            console.printf(string.format("Line #%d, length of %d, contents: %s", i, Stream[i].Length, e));
        }*/

        return self;
    }

    // Peek, return char on Line at Head
    string Peek() { return CharAt(Line, Head); }

    int PeekB() { return CharAt(Line, Head).ByteAt(0); }

    // PeekTo given length.  Moves Head and Line
    string PeekTo(int len = 1)
    {
        string s = "";

        if (!(Head >= 0 && Head < Stream[Line].Length) ||
            !(Head + len <= Stream[Line].Length))
        {
            Head = 0;
            Line++;
        }
        else if (!(len > 0 && len <= Stream[Line].Length))
            return s;

        for (int i = 0; i < len; i++)
            s.AppendFormat("%s", CharAt(Line, i + Head));

        console.printf(string.Format("\chPeekTo\cc, Line: %d, Head: %d, len: %d, Line Length: %d, Peek Contents: %s", Line, Head, len, Stream[Line].Length, s));

        Head += len;
        return s;
    }

    // Same as PeekTo, just does not move Head or Line
    string PeekFor(int at = -1, int len = 1)
    { 
        string s = "";
        int h = at == -1 ? Head : at, 
            l = Line;
        /*if (!(Head >= 0 && Head < Stream[Line].Length) ||
            !(Head + len <= Stream[Line].Length))
        {
            console.printf("peek for next line");
            h = 0;
            l++;
        }
        else*/ if (!(len > 0 && len <= Stream[Line].Length))
        {
            console.printf("\cgPeekFor got bullshit length?!");
            return s;
        }

        for (int i = 0; i < len; i++)
            s.AppendFormat("%s", CharAt(l, i + h));

        console.printf(string.Format("\chPeekFor\cc, Line: %d, Head: %d, len: %d, Line Length: %d, Peek Contents: %s", Line, Head, len, Stream[Line].Length, s));

        return s;       
    }

    /*
        PeekEnd - a.k.a. Get End of Block

        What the end of block is can be defined.

        Returns the explicit line in the Stream to
        access next, but it does not directly set the
        Line member.  The parser will do that.

        "from" is flagged "out", this should be the
        read head of the parser and will be set
        to the index to pick up at.
    
    */
    int PeekEnd (string c)
    {
        // Check each line, including this one
        int r = Head;
        for (int i = Line; i < Lines(); i++)
        {
            for (int j = r; j < Stream[i].Length; j++)
            {
                //console.printf(string.format("Looking for character: %s -- Examining character, line %d, head %d, %s", c, i, j, CharAt(i, j)));
                if ((CharAt(i, j).ByteAt(0) == c.ByteAt(0)) &&          // Does the first character match?
                    (c.Length() == 2 && j + 1 < Stream[i].Length ?      // Do we need to look for another character?
                        (CharAt(i, j + 1).ByteAt(0) == c.ByteAt(1)) :   // Yes, check next character 
                        true))                                          // Skip this part of the check
                {
                    // Is there more after?
                    if (j + c.Length() < Stream[i].Length)
                    {
                        console.printf(string.format("\chPeekEnd\cc - There's more after the terminator, head at : %d, moving to %d, line %d", Head, j + c.Length(), i));
                        Head = j + c.Length();
                        return i;
                    }
                    // No, go to the next line.
                    else
                    {
                        console.printf("\chPeekEnd\cc - Go to the next line");
                        Head = 0;
                        return i + 1;
                    }
                }
                else if (c.Length() == 1 && IsCodeChar(CharAt(i, j).ByteAt(0)))
                    return -1;
            }
            r = 0;
        }

        return -1; // We found nothing, which means something isn't closed, and now errors.
    }

    /*
        Returns boolean, checks if given string is a code character
    */
    private bool IsCodeChar(int b)
    {
        if (b == 34 || b == 44 || b == 123 || b == 125 || b == 59 || b == 47 || b == 42)
            return true;

        return false;
    }

    /* - END OF METHODS - */
}