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
    int TrueLine;   // This is the actual line number in the file - for error output

    // Each character is stored as a string in the array - be nice to have actual chars
    array<string> Chars;

    int Length() { return Chars.Size(); }
    /*
        This was written when it was a possible bug
        that the Chars array might contain empty slots
        post-santization, therefore this was needed to
        compare array.Size() versus the full condition
        to determine if the bug was real.

        UsedLength is preserved as an option for an edge-case
        where the array may not be void of empty strings.
    */
    int UsedLength()
    {
        int tl = 0;
        for (int i = 0; i < Chars.Size(); i++)
        {
            if (Chars[i] != "")
                tl++;
        }

        return tl;
    }

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
            at < Length() && at + len < Length())
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
        for (int i = 0; i < Length(); i++)
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

        self.TrueLine = TrueLine;

        if (self.Length() > 0)
            return self;
        else
            return null;
    }
}


/*
    This is the actual "file stream" representation of the file.
    The string that is read from a file, called the "raw lump",
    is processed into an array structure of characters.

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
        LumpHash;       // This value is calculated by hashing the contents of the lump and is used to eliminate duplicate reads

    /*
        Wrapper for resetting the stream
    */
    void Reset() { Line = Head = 0; }

    /*
        Wrapper for the two steps it takes to move to the next line
    */
    void NexLine()
    {
        Line++;
        Head = 0;
    }

    /*
        Returns the global index in the stream,
        which is the count of total characters
        read thus far.
    */
    int StreamIndex()
    {
        int si = 0;
        for (int i = 0; i < Line; i++)
            si += Stream[i].Length();
        return si + Head;
    }

    /*
        Returns the total count of characters in the stream
    */
    int StreamLength()
    {
        int sl = 0;
        for (int i = 0; i < Stream.Size(); i++)
            sl += Stream[i].Length();
        return sl;
    }

    /*
        Returns the length of the current line
    */
    int LineLength() { return Stream[Line].Length(); }

    /*
        Returns the length of the line in the stream at the given index
    */
    int LineLengthAt(int at) { return Stream[at].Length(); }

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

        NOTE! The duplicate read problem is fixed, however
        I decided to leave this feature more for informational
        purposes now than anything; maybe a failsafe.
    
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
        Returns the character on the given line at the given read index,
        or nothing if the given read index is beyond the line length.

    */
    string CharAt(int line, int head) { return head < Stream[line].Length() ? Stream[line].Chars[head] : ""; }

    /*
        Returns byte code of CharAt
    */
    int ByteAt(int line, int head) { return CharAt(line, head).ByteAt(0); }

    /*
        Stream constructor
    
    */
    FileStream Init(string RawLump, int LumpNumber, bool mode = false)
    {
        self.Reset();
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

        self.StreamOut();

        return self;
    }

    /*
        Outputs the contents of the stream for debugging purposes
    */
    void StreamOut()
    {
        console.printf(string.Format("File Stream contains %d lines.  Contents:", Stream.Size()));
        for (int i = 0; i < Stream.Size(); i++)
        {
            string e = "";
            for (int j = 0; j < Stream[i].Length(); j++)
                e.AppendFormat("%s", Stream[i].Chars[j]);
            console.printf(string.format("Line #%d, length of %d, contents: %s", i, Stream[i].Length(), e));
        }
    }

    // Peek, return char on Line at Head
    string Peek() { return Stream[Line].Chars[Head]; }

    // PeekB, same as Peek, just returns the byte code
    int PeekB() { return Stream[Line].Chars[Head].ByteAt(0); }

    // PeekTo given length.  Moves Head and Line
    string PeekTo(int len = 1)
    {
        string s = "";

        if (!(Head >= 0 && Head < Stream[Line].Length()) ||
            !(Head + len <= Stream[Line].Length()))
        {
            Head = 0;
            Line++;
        }
        else if (!(len > 0 && len <= Stream[Line].Length()))
            return s;

        for (int i = 0; i < len; i++)
            s.AppendFormat("%s", Stream[Line].Chars[i + Head]);

        console.printf(string.Format("\chPeekTo\cc, Line: %d, Head: %d, len: %d, Line Length: %d, Peek Contents: %s", Line, Head, len, Stream[Line].Length(), s));

        Head += len;
        return s;
    }

    /*
        Wrapper of PeekTo, but will also return the byte code
        It is assumed that the peek is for only one char
    */
    string, int PeekToB() 
    {
        string c = PeekTo();
        return c, c.ByteAt(0);
    }

    /*
        PeekEnd - a.k.a. Get End of Block

        What the end of block is can be defined.

        Returns the explicit line in the Stream to
        access next, but it does not directly set the
        Line member.  The parser should check the
        return before setting Line.

        PeekEnd does set Head.
    
    */
    int PeekEnd (string c, ZMLCharSet cs)
    {
        // Check each line, including this one
        int r = Head;
        for (int i = Line; i < Lines(); i++)
        {
            for (int j = r; j < Stream[i].Length(); j++)
            {
                console.printf(string.format("Looking for character: %s -- Examining character, line %d, head %d, %s", c, i, j, CharAt(i, j)));
                if ((CharAt(i, j).ByteAt(0) == c.ByteAt(0)) &&      // Does the first character match?
                    (c.Length() > 1 ?                               // Do we need to look for more characters?
                        mul_charCheck(c, i, j) :                    // Yes, get the result of Multi-Char Check
                        true))                                      // No, skip this check, good that's a loop in a check
                {
                    // Is there more after?
                    if (j + c.Length() < Stream[i].Length())
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
                else if (c.Length() == 1 && IsCodeChar(Stream[i].Chars[j].ByteAt(0), cs))
                    return -1;
            }
            r = 0;
        }

        return -1; // We found nothing, which means something isn't closed, and now errors.
    }

    /*
        Multi-Char Check - lets PeekEnd look for more than two characters as a terminator sequence.  Yay!
    */
    private bool mul_charCheck(string c, int l, int h)
    {
        int q = 1;
        if (h + c.Length() - 1 < Stream[l].Length())
        {
            for (int i = 1; i < c.Length(); i++)
            {
                if (CharAt(l, h + i).ByteAt(0) == c.ByteAt(i))
                    q++;
            }
            return (q == c.Length());
        }
        else
            return false;
    }

    /*
        Returns boolean, checks if given string is a code character
    */
    bool IsCodeChar(int b, in ZMLCharSet cs)
    {
        for (int i = 0; i < cs.CodeChars.Size(); i++)
        {
            if (b == cs.CodeChars[i])
                return true;
        }

        return false;
    }

    /*
        Returns boolean, checks if the given string is alphanumeric
    */
    bool IsAlphaNum(int b)
    {
        if ((b > 47 && b < 58) || (b > 64 && b < 91) || (b > 96 && b < 123))
            return true;

        return false;
    }

    /* - END OF METHODS - */
}