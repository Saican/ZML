/*

    What: Z-xtensible Markup Language Parser Event Handler
    Who: Sarah Blackburn
    When: 05/02/22

*/


class ZMLHandler : EventHandler
{
    string ZMLVersion;

    // Contains the contents of each def lump, without whitespace
    array<FileStream> defStreams;
    // Counts how many files failed to parse
    int abortCount;
    // Checks the array to see if any streams have the same hash
    bool HaveStream(int h)
    {
        for (int i = 0; i < defStreams.Size(); i++)
        {
            if (defStreams[i].LumpHash == h)
                return true;
        }

        return false;
    }

    // Reads each def lump into the defStreams array - without hashing files this function would cause duplicates!
    void Generate_DefStreams(int l = 0)
    {
        do
        {
            string rl = Wads.ReadLump(Wads.FindLump("zmldefs", l));
            if (!HaveStream(FileStream.GetLumpHash(rl)))
                defStreams.Push(new("FileStream").Init(rl, l));
            else
                console.printf("\t\t\ciZML Warning! \ccNo big deal, but tried to read the same lump twice!");
            l++;
        } while ((l = Wads.FindLump("zmldefs", l)) != -1);
    }


    /*
        So the fuck is a token?

        A token is a word that represents part of the
        defined syntax of the code the lexer or parser
        is attempting to interpret.

    */
    enum LTOKEN
    {
        T_MORE, // Keep going lexer
        T_MOREPREDICT_COMMENT, // That's something interesting, see if we can just predict and move on
        T_MOREPREDICT_KEY,  // It's a letter "t" or "a"
        T_KEY_TAG,
        T_KEY_ATTRIBUTE,
        T_NAME,
        T_TYPE,

        // These are errors
        T_IDKWHAT = -1,
        T_IDKWHAT_OPENCOMMENT = -2,
        T_IDKWHAT_OOB_AT = -3,
        T_IDKWHAT_OOB_LEN = -4,
        T_IDKWHAT_EOF = -5,
    };

    LTOKEN stringToToken(string e)
    {
        // Prediction
        if (e ~== "/")
            return T_MOREPREDICT_COMMENT;
        if (e ~== "t" || e ~== "a")
            return T_MOREPREDICT_KEY;
        // Probably never get these this way
        if (e ~== "tag")
            return T_KEY_TAG;
        if (e ~== "attributes")
            return T_KEY_ATTRIBUTE;
        else
            return T_MORE;

    }

    LTOKEN stringToErrorCheck(string e)
    {
        if (e ~== "OOB_at")
            return T_IDKWHAT_OOB_AT;
        if (e ~== "OOB_len")
            return T_IDKWHAT_OOB_LEN;
        if (e ~== "EOF")
            return T_IDKWHAT_EOF;
        else
            return T_IDKWHAT;
    }

    string errorToString(LTOKEN t)
    {
        switch (t)
        {
            case T_IDKWHAT_OOB_AT: return "OOB_AT";
            case T_IDKWHAT_OOB_LEN: return "OOB_LEN";
            case T_IDKWHAT_EOF: return "EOF";
            case T_IDKWHAT_OPENCOMMENT: return "OPENCOMMENT";
            default:
            case T_IDKWHAT: return "IDKWHAT";
        }
    }

    void AbortFile(FileStream file, LTOKEN t)
    {
        switch (t)
        {
            default:
            case T_IDKWHAT:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, contains an unidentified error, starting at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(t), t, file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_OPENCOMMENT:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, contains an unclosed block comment, starting at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(t), t,  file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_OOB_AT:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, caused an out of bounds reader, starting at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(t), t,  file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_OOB_LEN:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, caused an out of bounds read length, starting at lin e# \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(t), t,  file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_EOF:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, read attempt reached the end of the file without finding valid data! Last known valid data started at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(t), t,  file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
        }

        file.Line = file.Lines();
        abortCount++;
    }

    void Lexer(FileStream file, out int reader, out string e, out int t, int len)
    {
        string pt;
        bool found;
        [pt, found] = file.PeekJob(reader, len);
        if (found)
        {
            e = string.Format("%s%s", e, pt);
            t = stringToToken(e);
        }
        else
            t = stringToErrorCheck(pt);        
    }

    array<ZMLTag> taglist;

    // This is the actual lexer/parser loop
    void Generate_TagArray()
    {
        // Loop through the defStreams array
        for (int i = 0; i < defStreams.Size(); i++)
        {
            FileStream file = defStreams[i];  // Instead of doing defStreams[i].blah for everything, just do file.blah
            /*
                There are 2 read heads - the Line member of the FileStream
                and "reader".  The Line member controls which line of the file
                will be accessed by Peek and PeekTo.  "reader" controls the
                character index of that line.

                Line is initialized to 0 when the FileStream is created
            */
            int reader = 0;
            LTOKEN t = T_MORE;
            for (; file.Line < file.Lines(); file.Line++)  // Lines() returns the Size() of the Stream array
            {
                string e = "";
                // Tokeninzing returns something no matter what, either get more string, or error, until it's not that
                while (t == T_MORE)
                    Lexer(file, reader, e, t, 1);

                // Parsing is basically, the Lexer gave us a valid "t" value, so do something as a result
                switch (t)
                {
                    // The string contained a backslash - it's likely a comment
                    case T_MOREPREDICT_COMMENT:
                        // Figure out if it's a single line or a block comment
                        e = string.Format("%s%s", e, file.Peek(reader));
                        if (e ~== "/*")  // Ok, figure out where the eob is
                        {
                            int nextLine = file.GetEOB(reader, "*/");  // GetEOB will return -1 if the block isn't closed, so don't just set file.Line to it.
                            if (nextLine != -1)
                                file.Line = nextLine - 1;
                            else
                                t = T_IDKWHAT_OPENCOMMENT;  // Block is not closed, abort
                        }
                        else // It's a line comment, reset reader and let it loop to next line
                            t = reader = 0; // t = 0 = T_MORE
                        break;

                    // The string starts with a letter "t" or "a", which is a good sign it's a keyword
                    case T_MOREPREDICT_KEY:
                        if (e ~== "t")
                        { 
                            string el = string.Format("%s%s", e, file.PeekFor(reader, 2));
                            if (el != "tag")
                                t = stringToErrorCheck(el);
                            else
                                Lexer(file, reader, e, t, 2);
                        }
                        else if (e ~== "a")
                        {
                            string el = string.Format("%s%s", e, file.PeekFor(reader, 9));
                            if (el != "attributes")
                                t = stringToErrorCheck(el);
                            else
                                Lexer(file, reader, e, t, 9);
                        }
                        break;
                    case T_KEY_TAG:
                        if (file.Stream[file.Line].Chars[file.Stream[file.Line].Length - 1] == ";")
                        {}
                        else
                            t = T_KEY_ATTRIBUTE;
                        break;
                    case T_KEY_ATTRIBUTE:
                        break;
                }

                if (t < 0) // Oh no, error handle
                    AbortFile(file, t);
            }
        }
    }

    override void OnRegister()
    {
        // This mess creates the nice greeting ZML sends to the console.
        ZMLVersion = "0.1";
        string greeting = "Greetings! I am the Z-xtensible Markup Language Parser Event System, ";
        string vers = "version: ";
        int greetlen = string.Format("%s%s%s", greeting, vers, ZMLVersion).Length();
        string fullGreeting = string.Format("\n\n\cx%s\cc%s\cy%s\n\cx", greeting, vers, ZMLVersion);
        for (int i = 0; i < greetLen; i++)
            fullGreeting = string.Format("%s%s", fullGreeting, "-");
        console.printf(fullGreeting);

        // Dead baby jokes aside, default the count
        abortCount = 0;
        // Ok, read ZMLDEFS lumps into file streams
        Generate_DefStreams();
        console.printf(string.Format("\t\t\cdZML successfully read \cy%d \cdtag definition lumps into file streams!\n\t\t\t\t\cc- This means the ZMLDEFS files are in a parse-able format, it does not mean they are valid.\n\n", defStreams.Size()));
        // Assuming that there are now file streams, try to make the tag lists
        Generate_TagArray();
        // Well, no, something was wrong - it got handled but bitch and moan anyway
        if (abortCount > 0)
            console.printf(string.Format("\n\t\t\ciZML failed to parse \cg%d \citag definition lumps!\n\t\t\t\t\cc- This means ZML encountered a problem with the file%s and stopped trying to create usable data from %s. Reported errors need fixed.\n\n", abortCount, (abortCount > 1 ? "s" : ""), (abortCount > 1 ? "them" : "it")));
        // Nevermind, yay!  We win!
        else
            console.printf(string.format("\n\t\t\cyZML successfully parsed \cx%d \cyZMLDEFS lumps into \cx%d \cyZML tags!\n\n", defStreams.Size(), taglist.Size()));
    }

    /* - END OF METHODS - */
}

