/*
    What : ZML Tag Definition (ZMLDEFS) Parser
    Who : Sarah Blackburn
    When : 19/03/2022

*/


class ZML_DefParser
{
    const CHAR_ID_DOUBLEQUOTE = 34;
    const CHAR_ID_ASTERISK = 42;
    const CHAR_ID_COMMA = 44;
    const CHAR_ID_BACKSLASH = 47;
    const CHAR_ID_SEMICOLON = 59;
    const CHAR_ID_UNDERSCORE = 95;
    const CHAR_ID_OPENBRACE = 123;
    const CHAR_ID_CLOSEBRACE = 125;

    // Contents of each file
    array<FileStream> Streams;
    // Counts how many files failed to parse
    int defParseFails;
    array<StreamError> parseErrors;

    ZML_DefParser Init()
    {
        // Initialize internals
        defParseFails = 0;
        int streamSize = Generate_Streams();
        for (int i = 0; i < streamSize; i++)
        {
            array<DefToken> parseList;
            // Sanitize Comments, 
            // then check continuity (check for most of the basic errors),
            // lastly generate token list - this is what to do and where in the stream
            if (Sanitize_StreamComments(Streams[i]) ? 
                (Check_StreamContinuity(Streams[i]) ? 
                    Tokenize(Streams[i], parseList) : 
                    false) : 
                false)
                // All of that worked?  Ok
                Parse_DefLumps(Streams[i], parseList);
            else
                defParseFails++;
        }
        
        // Error output
        if (defParseFails > 0)
        {
            console.printf(string.Format("\n\t\t\ciZML failed to parse \cg%d \citag definition lumps!\n\t\t\t\t\cc- This means ZML encountered a problem with the file%s and stopped trying to create usable data from %s. Reported errors need fixed.\n\n", defParseFails, (defParseFails > 1 ? "s" : ""), (defParseFails > 1 ? "them" : "it")));

            for (int i = 0; i < parseErrors.Size(); i++)
            {
                StreamError error = parseErrors[i];
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump: #\ci%d\cg, Lump Hash: \ci%d\cg, Message: \ci%s\cg\n\t\t\t - Contents of Lexer: \ci%s \cg- Last known valid data started at line: #\cii:%d\cg(\cyf:%d\cg)!\n\t\t\t - Line contents: \cc%s",
                    error.CodeString, error.CodeId, error.LumpNumber, error.LumpHash, error.Message, error.StreamBufferContents, error.InternalLine, error.FileLine, error.FullLine));
            }
        }
        // Nevermind, yay!  We win!
        /*else
        {
            console.printf(string.format("\n\t\t\cyZML successfully parsed \cx%d \cyZMLDEFS lumps into \cx%d \cyZML tags!\n\n", Streams.Size(), taglist.Size()));

            for (int i = 0; i < taglist.Size(); i++)
            {
                string al = " -- Tag contains attributes: ";
                for (int j = 0; j < taglist[i].attributes.Size(); j++)
                    al.AppendFormat("%s (type:%d), ", taglist[i].attributes[j].name, taglist[i].attributes[j].type);

                console.printf(string.Format("Tag is named (type%d): %s%s", taglist[i].type, taglist[i].name, taglist[i].attributes.Size() > 0 ? al : ""));
            }
        }*/

        return self;
    }

    // Checks the array to see if any streams have the same hash
    private bool, int HaveStream(int h)
    {
        for (int i = 0; i < Streams.Size(); i++)
        {
            if (Streams[i].LumpHash == h)
                return true, i;
        }

        return false, -1;
    }

    /* 
        Reads each def lump into the Streams array
    */
    private int Generate_Streams(int l = 0)
    {
        while ((l = Wads.FindLump("zmldefs", l)) != -1)
        {
            // Read the lump into a string - there should be the base ZMLDEFS in the ZML package
            string rl = Wads.ReadLump(l);
            // HaveStream returns bool, int
            bool hs;
            int ds;
            // Check if the lump has already been read - hs will be false if not, and ds will be the index in the file stream array if true
            [hs, ds] = HaveStream(FileStream.GetLumpHash(rl));
            if (!hs)
                Streams.Push(new("FileStream").Init(rl, l));
            else
                console.printf(string.Format("\t\t\ciZML Warning! \ccNo big deal, but tried to read the same lump twice! Original lump # \ci%d\cc, duplicate lump # \ci%d", Streams[ds].LumpNumber, l));

            l++;
        }

        console.printf(string.Format("\t\t\cdZML successfully read \cy%d \cdtag definition lumps into file streams!\n\t\t\t\t\cc- This means the ZMLDEFS files are in a parse-able format, it does not mean they are valid.\n\n", Streams.Size()));
        return Streams.Size();
    }

    /*
        Stream creation, by default, removes whitespace,
        but does not remove comments.  So each stream needs
        fixed before checking continuity.

    */
    private bool Sanitize_StreamComments(in out FileStream file)
    {
        string e = "";
        while (file.StreamIndex() < file.StreamLength())
        {
            e.AppendFormat("%s", file.PeekTo());
            if (e.ByteAt(0) == CHAR_ID_BACKSLASH)
            {
                // Block comment
                if (file.PeekB() == CHAR_ID_ASTERISK)
                {
                    // Go back one char to  pick up the backslach
                    int ws = file.Head - 1;
                    // Find where the end of the comment is
                    int nextLine = file.PeekEnd("*/");
                    // Found it
                    if (nextLine != -1)
                    {
                        // Delete the lines containing the comment
                        for (int i = file.Line; i <= nextLine; i++)
                        {
                            // The loop goes to nexLine, but if the stream head is 0,
                            // then there's no more comment to remove, so break.
                            if (i == nextLine && file.Head == 0)
                                break;

                            // Establish how many chars to delete
                            int dt;
                            // If at the end of the comment, go to wherever the stream head is
                            if (i == nextLine)
                                dt = file.Head;
                            // Otherwise go the entire line length
                            else
                                dt = file.LineLengthAt(i);

                            // Delete the chars in the line
                            for (int j = ws; j < dt; j++)
                                file.Stream[i].Chars.Delete(ws > 0 ? ws : 0);

                            // Fix the array
                            file.Stream[i].Chars.ShrinkToFit();

                            // This variable allows the loop to delete the beginning of comments
                            // that are on lines with valid code before the comment.  So after the
                            // first line of the comment, this variable must be reset to 0 to delete
                            // entire lines.
                            ws = 0;
                        }

                        // PeekEnd returns the explicit line to move to, but does not set it.
                        file.Line = nextLine;
                    }
                    else
                    {
                        /* Throw open comment error -2 */
                        parseErrors.Push(new("StreamError").Init(StreamError.ERROR_ID_OPENCOMMENT, 
                            file.LumpNumber, 
                            file.LumpHash, 
                            "UNCLOSED BLOCK COMMENT!", 
                            e, 
                            file.Line, 
                            file.Stream[file.Line].TrueLine, 
                            file.Stream[file.Line].FullLine()));
                        return false;    
                    }
                }
                // Line comment
                else if (file.PeekB() == CHAR_ID_BACKSLASH)
                {
                    // MUCH simpler, line comments just remove anything after the backslashes
                    // Because this is messing with the line length, the LineLength function
                    // becomes indeterminate, so the original length gets stored and used instead.
                    // It APPEARS that array.Delete deletes whatever is at the given index, moves everything
                    // after to the left, but does not resize the array, thus hammering at one index,
                    // for the total orginal length of the array, is perfectly safe.
                    // This also ensures partial and entire lines are handled.
                    int dt = file.LineLength();
                    // Delete the chars in the line - basically same thing as block comments
                    for (int i = file.Head - 1; i < dt; i++)
                        file.Stream[file.Line].Chars.Delete(file.Head - 1);
                    // Fix the array
                    file.Stream[file.Line].Chars.ShrinkToFit();
                    // Go to the next line
                    file.NexLine();
                }
                else
                {
                    /* Throw unexpected character error -5 */
                    parseErrors.Push(new("StreamError").Init(StreamError.ERROR_ID_UNEXPECTEDCODE, 
                        file.LumpNumber, 
                        file.LumpHash, 
                        "UNEXPECTED CHARACTER READ!", 
                        e, 
                        file.Line, 
                        file.Stream[file.Line].TrueLine, 
                        file.Stream[file.Line].FullLine()));
                    return false;
                }
            }

            // Last step, clear the buffer, we need to reach each character individually.
            e = "";
        }

        // Remove empty lines from the stream
        for (int i = 0; i < file.Lines(); i++)
        {
            if (file.LineLengthAt(i) == 0)
                file.Stream.Delete(i--);
        }
        file.Stream.ShrinkToFit();

        // Reset the stream
        file.Reset();

        file.StreamOut();
        return true;
    }

    /*
        Checks each file for continuity - this means quotes are closed, braces are closed,etc.

        This function is a clusterfuck of just jfc...facepalm.
        *Head hits keyboard.
    */
    private bool Check_StreamContinuity(in out FileStream file)
    {
        int qc = 0,     // Quote count
            cc = 0,     // Comma count
            obc = 0,    // Open brace count
            cbc = 0;    // Close brace count
        // Read entire stream
        while (file.StreamIndex() < file.StreamLength())
        {
            string c;
            int b;
            [c, b] = file.PeekToB();
            // Check it's a valid char
            if (file.IsCodeChar(b))
            {
                // Yes, what is it? Increment that counter.
                switch (b)
                {
                    case CHAR_ID_DOUBLEQUOTE: qc++; break;
                    case CHAR_ID_COMMA: cc++; break;
                    case CHAR_ID_OPENBRACE: obc++; break;
                    case CHAR_ID_CLOSEBRACE: cbc++; break;
                }
            }
            // No, ok, it's not an underscore right, that's valid too, is it alpha-numeric?
            else if (b != CHAR_ID_UNDERSCORE && !file.IsAlphaNum(b))
            {
                // Nope, add invalid char to error list -3
                parseErrors.Push(new("StreamError").Init(StreamError.ERROR_ID_INVALIDCHAR, 
                    file.LumpNumber, 
                    file.LumpHash, 
                    "INVALID CHARACTER DETECTED!", 
                    c, 
                    file.Line, 
                    file.Stream[file.Line].TrueLine, 
                    file.Stream[file.Line].FullLine()));
                return false;
            }
        }

        // Assuming success the stream needs reset
        file.Reset();

        // Quote count - should be 2 for each word, thus remainder should be 0
        if (qc % 2 != 0)
        { 
            // Go line by line
            for (int i = 0; i < file.Lines(); i++)
            {
                int lqc = 0;
                // Read each char and count the number of quotes encountered
                for (int j = 0; j < file.LineLengthAt(i); j++)
                {
                    if (file.ByteAt(i, j) == CHAR_ID_DOUBLEQUOTE)
                        lqc++;
                }

                // If the number is more than zero and not four, that's the problem line.
                if (lqc > 0 && lqc != 4)
                {
                    // Add missing quote to error list
                    parseErrors.Push(new("StreamError").Init(StreamError.ERROR_ID_OPENSTRING, 
                        file.LumpNumber, 
                        file.LumpHash, 
                        "UNCLOSED STRING FOUND!", 
                        "", 
                        i, 
                        file.Stream[i].TrueLine, 
                        file.Stream[i].FullLine()));
                    return false;
                }
            }
        }

        // Comma count - should be 1 for every 4 quotes
        if (cc != qc / 4)
        { 
            // Oh boy! Go line by line again
            for (int i = 0; i < file.Lines(); i++)
            {
                bool bc = false;
                // Read each char again!
                for (int j = 0; j < file.LineLengthAt(i); j++)
                {
                    // Did we get a quotation?
                    if (file.ByteAt(i, j) == CHAR_ID_DOUBLEQUOTE)
                    {
                        // Crap!  Ok, read the line again and see if there's a comma
                        for (int k = 0; k < file.LineLengthAt(i); k++)
                        {
                            // Omg there is, get out of this loop now!
                            if (file.ByteAt(i, k) == CHAR_ID_COMMA)
                            {
                                bc = true;
                                break;
                            }
                        }
                        // There was not, that would be the problem line
                        if (!bc)
                        {
                            // Add missing comma to error list -6
                            parseErrors.Push(new("StreamError").Init(StreamError.ERROR_ID_MISSINGCOMMA, 
                                file.LumpNumber, 
                                file.LumpHash, 
                                "COMMA (,) MISSING BETWEEN NAME AND TYPE OF ELEMENT!", 
                                "", 
                                i, 
                                file.Stream[i].TrueLine, 
                                file.Stream[i].FullLine()));
                            return false;
                        }
                    }
                }
            }
        }

        // Open brace count - should be equal to close brace count
        if (obc < cbc)
        {
            int lobc = 0,
                lcbc = 0;
            // Go line by line, but in reverse!
            for (int i = file.Lines() - 1; i >= 0; i--)
            {
                // Ok read each char from left to right like normal
                for (int j = 0; j < file.LineLengthAt(i); j++)
                {
                    // Is it a close brace?  Increment the counter
                    if (file.ByteAt(i, j) == CHAR_ID_CLOSEBRACE)
                        lcbc++;
                    // No, ok the close brace counter has counted braces and we've encountered an open brace
                    else if (lcbc > 0 && file.ByteAt(i, j) == CHAR_ID_OPENBRACE)
                    {
                        // Start over, from where we're at, so this starts the line loop again
                        for (int k = i; k >= 0; k--)
                        {
                            int mj = k == i ? j : 0;
                            // Read the chars in the line
                            for (int m = mj; m < file.LineLengthAt(k); m++)
                            {
                                // If is an open brace, increment the counter
                                if (file.ByteAt(k, m) == CHAR_ID_OPENBRACE)
                                    lobc++;
                                // No, its a close brace, which should be the next set of braces, so check the count.
                                // If open brace count is less than close brace count, this is our error line.
                                // Good god the getting here.
                                else if (file.ByteAt(k,m) == CHAR_ID_CLOSEBRACE || (k == 0 && lobc < lcbc))
                                {
                                    // Add missing open brace to error list
                                    parseErrors.Push(new("StreamError").Init(StreamError.ERROR_ID_MISSINGOPENBRACE, 
                                        file.LumpNumber, 
                                        file.LumpHash, 
                                        "OPEN BRACE ( { ) MISSING!", 
                                        "", 
                                        k, 
                                        file.Stream[k].TrueLine, 
                                        file.Stream[k].FullLine()));
                                    return false;
                                }
                            }
                        }
                    }
                }
            }
        }
        // Close brace count - should be equal to open brace count
        else if (cbc < obc)
        {
            int lobc = 0,
                lcbc = 0;
            // Go line by line, normally this time
            for (int i = 0; i < file.Lines(); i++)
            {
                // Ok read each char from left to right like normal
                for (int j = 0; j < file.LineLengthAt(i); j++)
                {
                    // Is it a open brace?  Increment the counter
                    if (file.ByteAt(i, j) == CHAR_ID_OPENBRACE)
                        lobc++;
                    // No, ok the open brace counter has counted braces and we've encountered a close brace
                    else if (lobc > 0 && file.ByteAt(i, j) == CHAR_ID_CLOSEBRACE)
                    {
                        // Start over, from where we're at, so this starts the line loop again
                        for (int k = i; k < file.Lines(); k++)
                        {
                            int mj = k == i ? j : 0;
                            // Read the chars in the line
                            for (int m = mj; m < file.LineLengthAt(k); m++)
                            {
                                // If is an open brace, increment the counter
                                if (file.ByteAt(k, m) == CHAR_ID_CLOSEBRACE)
                                    lcbc++;
                                // No, its an open brace, which should be the next set of braces, so check the count.
                                // If close brace count is less than open brace count, this is our error line.
                                // Good god the getting here...twice.
                                else if (file.ByteAt(k,m) == CHAR_ID_OPENBRACE || (k == file.Lines() -1 && lcbc < lobc))
                                {
                                    // Add missing close brace to error list
                                    parseErrors.Push(new("StreamError").Init(StreamError.ERROR_ID_MISSINGCLOSEBRACE, 
                                        file.LumpNumber, 
                                        file.LumpHash, 
                                        "CLOSE BRACE ( } ) MISSING!", 
                                        "", 
                                        k, 
                                        file.Stream[k].TrueLine, 
                                        file.Stream[k].FullLine()));
                                    return false;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Semicolon check - read each line, like normal
        for (int i = 0; i < file.Lines(); i++)
        {
            // Read each char, like normal
            for (int j = 0; j < file.LineLengthAt(i); j++)
            {
                // The line has to have a quote in it, 
                // then the end of the line should either 
                // be a semicolon or and open brace;
                // I allow for both brace styles this way.
                if (file.ByteAt(i, j) == CHAR_ID_DOUBLEQUOTE &&
                    (file.ByteAt(i, file.LineLengthAt(i) - 1) != CHAR_ID_SEMICOLON ? 
                        file.ByteAt(i, file.LineLengthAt(i) - 1) != CHAR_ID_OPENBRACE :
                        false) &&
                    file.ByteAt(i + 1, 0) != CHAR_ID_OPENBRACE)
                {
                    // Add missing semicolon to error list
                    parseErrors.Push(new("StreamError").Init(StreamError.ERROR_ID_MISSINGEOB, 
                        file.LumpNumber, 
                        file.LumpHash, 
                        "END OF BLOCK ( ; ) MISSING!", 
                        "", 
                        i, 
                        file.Stream[i].TrueLine, 
                        file.Stream[i].FullLine()));
                    return false;
                }
            }
        }

        // Assuming none of the above fails and returns false,
        return true;
    }

    private bool Tokenize(in out FileStream file, in out array<DefToken> parseList)
    {
        string e = "";
        while (file.StreamIndex() < file.StreamLength())
        {
            string et = file.PeekTo();
            if (e.Length() > 0 && file.IsCodeChar(et.ByteAt(0)))
            {
                parseErrors.Push(new("StreamError").Init(StreamError.ERROR_ID_UNKNOWNIDENTIFIER,
                    file.LumpNumber,
                    file.LumpHash,
                    "UNKNOWN IDENTIFIER DETECTED!",
                    et,
                    file.Line,
                    file.Stream[file.Line].TrueLine,
                    file.Stream[file.Line].FullLine()));
                return false;
            }
            else
            {
                e.AppendFormat("%s", et);
                if (DefToken.StringToToken(e) != DefToken.WORD_NONE)
                {
                    switch (DefToken.StringToToken(e))
                    {
                        case DefToken.WORD_TAG:
                            console.printf("The word is tag!");
                            break;
                    }

                    e = "";
                }
            }
        }
        return true;
    }

    private void Parse_DefLumps(in out FileStream file, in out array<DefToken> parseList)
    {}

    /* - END OF METHODS - */
}