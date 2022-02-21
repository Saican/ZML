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
    int Length, TrueLine;
    array<string> Chars;

    string Mid(int at = 0, int len = 1)
    {
        string s = "";
        if (at >= 0 && len > 0 &&
            at < Length && at + len < Length)
        {
            for (int i = 0; i < len; i++)
                s = string.Format("%s%s", s, Chars[i + at]);
        }

        return s;
    }

    string FullLine()
    {
        string f = "";
        for (int i = 0; i < Length; i++)
            f = string.Format("%s%s", f, Chars[i]);
        return f;
    }

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
    array<StreamLine> Stream;
    int Lines() { return Stream.Size(); }
    int Line,
        LumpNumber,  // This is basically useless but interesting
        LumpHash;

    /*
        https://stackoverflow.com/questions/8317508/hash-function-for-a-string#:~:text=like%20e.g.-,%23define,-A%2054059%20/*%20a

        Its been a long while since I had a CS class
        that made me write my own hash function,
        so I just borrowed one from the link above.
    
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

    string CharAt(int line, int head) { return Stream[line].Chars[head]; }

    FileStream Init(string RawLump, int LumpNumber, bool mode = false)
    {
        self.Line = 0;
        self.LumpNumber = LumpNumber;
        self.LumpHash = FileStream.GetLumpHash(RawLump);

        // Break each line of the file into a StreamLine object
        string l = "";
        int tln = 1;    // This is the true line number, this is only for information during error output
        for (int i = 0; i < RawLump.Length(); i++)
        {
            string n = RawLump.Mid(i, 1);
            if (n != "\n")
                l = string.Format("%s%s", l, n);
            else if (l.Length() > 0)
            {
                StreamLine sl = new("StreamLine").Init(l, tln++);
                if (sl)
                    Stream.Push(sl);
                l = "";
            }
        }

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

    // Standard (pretty much) Peek(To) functions - these are aware of the line to be on
    string Peek(int at) { return CharAt(self.Line, at); }
    // Note that "head" is flagged "out", this should be the parser read head
    string PeekTo(int at, int len, out int head)
    {
        string s = "";
        if (at >= 0 && len > 0 &&
            at < Stream[Line].Length && at + len <= Stream[Line].Length)
        {
            for (int i = 0; i < len; i++)
                s = string.Format("%s%s", s, CharAt(Line, i + at));

            head += len;
        }

        return s;
    }
    // Wrapper for PeekTo which allows reading ahead without moving the head
    string PeekFor(int at, int len)
    { 
        int head;
        return PeekTo(at, len, head);
    }

    /*
        Get End of Block

        What the end of block is can be defined.

        Returns the explicit line in the Stream to
        access next, but it does not directly set the
        Line member.  The parser will do that.

        "from" is flagged "out", this should be the
        read head of the parser and will be set
        to the index to pick up at.
    
    */
    int GetEOB (out int from, string c)
    {
        // Check each line, including this one
        int r = from;
        for (int i = Line; i < Lines(); i++)
        {
            string e = "";
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
                        console.printf("There's more after the terminator");
                        from = j + c.Length();
                        return i;
                    }
                    // No, go to the next line.
                    else
                    {
                        console.printf("Go to the next line");
                        from = 0;
                        return i + 1;
                    }
                }
            }
            r = 0;
        }

        return -1; // We found nothing, which means something isn't closed, and now errors.
    }
}