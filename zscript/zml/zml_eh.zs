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
    int defParseFails;
    // Checks the array to see if any streams have the same hash
    bool, int HaveStream(int h)
    {
        for (int i = 0; i < defStreams.Size(); i++)
        {
            if (defStreams[i].LumpHash == h)
                return true, i;
        }

        return false, -1;
    }

    // Reads each def lump into the defStreams array - without hashing files this function would cause duplicates!
    void Generate_DefStreams(int l = 0)
    {
        do
        {
            string rl = Wads.ReadLump(Wads.FindLump("zmldefs", l));
            bool hs;
            int ds;
            [hs, ds] = HaveStream(FileStream.GetLumpHash(rl));
            if (!hs)
                defStreams.Push(new("FileStream").Init(rl, l));
            else
                console.printf(string.Format("\t\t\ciZML Warning! \ccNo big deal, but tried to read the same lump twice! Original lump # \ci%d\cc, duplicate lump # \ci%d", defStreams[ds].LumpNumber, l));
            l++;
        } while ((l = Wads.FindLump("zmldefs", l)) != -1);
    }


    /*
        LTOKEN's represent part of the
        ZMLDEFS syntax.  They are produced
        by the lexing portion of the tag list
        generator.

    */
    enum LTOKEN
    {
        T_END,
        T_MORE, // This is the standard, "please read from the file stream, lexer" token.  It means there's not enough info to make other tokens..

        // Keywords
        T_KEY_TAG,
        T_KEY_ATTRIBUTE,

        // Special Characters - context establishing tokens
        T_SPECIALCHAR_DOUBLEQUOTE,
        T_SPECIALCHAR_COMMA,
        T_SPECIALCHAR_OPENBRACE,
        T_SPECIALCHAR_CLOSEBRACE,
        T_SPECIALCHAR_SEMICOLON,
        T_SPECIALCHAR_BACKSLASH,
        T_SPECIALCHAR_ASTERISK,

        // Context dependent words - this means it matters where in the parser we are when reading these tokens
        T_WORD_NAME,
        T_WORD_TYPE,

        // These are errors
        T_IDKWHAT = -1,
        T_IDKWHAT_OPENCOMMENT = -2,
        T_IDKWHAT_INVALIDCHAR = -3,
        T_IDKWHAT_OPENSTRING = -4,
        T_IDKWHAT_UNEXPECTEDCODE = -5,
    };

    LTOKEN stringToToken()
    {
        // Keywords
        if (e ~== "tag")
            return T_KEY_TAG;
        if (e ~== "attributes")
            return T_KEY_ATTRIBUTE;

        // Special Characters
        if (e.Length() == 1)
        {
            int b = e.ByteAt(0);
            if (b == 34)
                return T_SPECIALCHAR_DOUBLEQUOTE;
            if (b == 44)
                return T_SPECIALCHAR_COMMA;
            if (b == 123)
                return T_SPECIALCHAR_OPENBRACE;
            if (b == 125)
                return T_SPECIALCHAR_CLOSEBRACE;
            if (b == 59)
                return T_SPECIALCHAR_SEMICOLON;
            if (b == 47)
                return T_SPECIALCHAR_BACKSLASH;
            if (b == 42)
                return T_SPECIALCHAR_ASTERISK;
        }
            
        return T_MORE;
    }

    bool IsCodeChar(string el)
    {
        if (el.Length() == 1)
        {
            int b = el.ByteAt(0);
            if (b == 34 || b == 44 || b == 123 || b == 125 || b == 59 || b == 47 || b == 42)
                return true;
        }

        return false;
    }

    bool IsAlphaNum(string el)
    {
        if (el.Length() == 1)
        {
            int b = el.ByteAt(0);
            if ((b > 47 && b < 58) || (b > 64 && b < 91) || (b > 96 && b < 123))
                return true;
        }

        return false;
    }

    LTOKEN stringToErrorCheck(string el)
    {
        if (el ~== "OPENC")
            return T_IDKWHAT_OPENCOMMENT;
        if (el ~== "INVLDC")
            return T_IDKWHAT_INVALIDCHAR;
        if (el ~== "OPENSTR")
            return T_IDKWHAT_OPENSTRING;
        else
        {
            if (IsCodeChar(e) || IsCodeChar(el))
                return T_IDKWHAT_UNEXPECTEDCODE;
            else if (IsAlphaNum(e) || IsAlphaNum(el))
                return T_IDKWHAT_INVALIDCHAR;
        }

        return T_IDKWHAT;
    }

    string errorToString()
    {
        switch (t)
        {
            case T_IDKWHAT_OPENCOMMENT: return "OPENCOMMENT";
            case T_IDKWHAT_INVALIDCHAR: return "INVALIDCHAR";
            case T_IDKWHAT_OPENSTRING: return "OPENSTRING";
            case T_IDKWHAT_UNEXPECTEDCODE: return "UNEXPECTEDCODE";
            default:
            case T_IDKWHAT: return "IDKWHAT";
        }
    }

    /*
        These bools establish contexts
    */
    bool bStartComment,
        bStartLineComment,
        bStartBlockComment,
        bBAD_CommentContext,

        bGetTagName,
        bGetAttributeName,
        bGetType,
        
        bFirstQuote,
        bLastQuote,
        bComma;

    void ZeroContexts()
    {
        bStartComment = false;
        bStartLineComment = false;
        bStartBlockComment = false;

        bGetTagName = false;
        bGetAttributeName = false;
        bGetType = false;

        bFirstQuote = false;
        bLastQuote = false;
        bComma = false;
    }

    /*
        The file being processed, the line read head, and the token generated by the lexer
        - There are 2 read heads, the global "reader" and file.Line, which determines which
          line of the file is being read.
    */
    FileStream file;
    int reader;
    LTOKEN t;
    string e;

    ZMLTag ztag;
    array<ZMLTag> taglist;

    // This is the actual lexer/parser loop
    void Parse_DefLumps()
    {
        // Loop through the defStreams array
        for (int i = 0; i < defStreams.Size(); i++)
        {
            // Default everything for the first pass
            // If a previous file terminated for errors, things may not be reset.
            file = defStreams[i];
            reader = 0;
            t = T_MORE;
            ztag = null;
            ZeroContexts();

            while (t > T_END)  // Signalling 0 will end the loop
            {
                // "e" is the raw untokenized string - it must be cleared each loop
                e = "";
                // Tokeninzing returns something no matter what, either get more string, or error, until it's not that
                while (t == T_MORE)
                {
                    e = string.Format("%s%s", e, file.PeekTo(reader, 1, reader));
                    t = stringToToken();
                }

                // Assumming we got a valid token, we can now establish context
                switch (t)
                {
                    case T_KEY_TAG:
                        // We got a tag def, so we'll initialize the ztag here, and then let the lexer loop
                        if (!ztag)
                            ztag = new("ZMLTag").Init("zml_empty", "t_none");

                        console.printf(string.format("Hey we got a tag! contents of e: %s, line is: %d, reader is at: %d", e, file.Line, reader));
                        break;
                    case T_KEY_ATTRIBUTE:
                        break;

                    case T_SPECIALCHAR_DOUBLEQUOTE:
                        console.printf("Found quotation");
                        if (bFirstQuote)
                            bLastQuote = true;
                        else
                            bFirstQuote = true;
                        break;

                    case T_SPECIALCHAR_COMMA:
                        break;
                    case T_SPECIALCHAR_OPENBRACE:
                        break;
                    case T_SPECIALCHAR_CLOSEBRACE:
                        break;
                    case T_SPECIALCHAR_SEMICOLON:
                        break;

                    case T_SPECIALCHAR_BACKSLASH:
                        // Have we encountered another backslash?
                        if (bStartComment)
                            bStartLineComment = true;
                        // This might be a comment, so peek the next char to make sure
                        else if (file.Peek(reader).ByteAt(0) == 42 || file.Peek(reader).ByteAt(0) == 47)
                            bStartComment = true;
                        break;

                    case T_SPECIALCHAR_ASTERISK:
                        // Have we encountered a backslash?
                        if (bStartComment)
                            bStartBlockComment = true;
                        break;
                }
            
                // Context should be established so do something about it.
                if (t > T_END)
                {
                    // Block Comment
                    if (bStartComment && bStartBlockComment)
                        Parse_DefLump_Context_BlockComment();
                    
                    // Line Comment
                    if (bStartComment && bStartLineComment)
                        Parse_DefLump_Context_LineComment();

                    // Likely the beginning of the name
                    if ((ztag ? ztag.Empty() : false) && bFirstQuote && !bLastQuote)
                        Parse_DefLump_Context_Word("\"");

                    // Likely the type of something
                }

                // Got here without t going negative?  Get some more! lol
                if (t > T_MORE)
                    t = T_MORE;
            }

            if (t < T_END)
                DefLump_ErrorOutput();
        }
    }

    /*
        Tokens are turned into "contexts",
        which is a fancy way of saying a bunch of
        booleans get switched on or off.

        The result of how those bools are set
        determines what each Contextulizer does.
    
    */
    void Parse_DefLump_Context_BlockComment()
    {
        console.printf("Context Block Comment");
        // GetEOB will search for the specified closing tag, setting reader in the process.
        // The return is the line to move to, however it will return -1 if nothing is found,
        // so we need to check it before setting file.Line.
        int nextLine = file.GetEOB(reader, "*/");
        if (nextLine != -1)
            file.Line = nextLine;
        else
            t = stringToErrorCheck("OPENC");

        bStartComment = bStartBlockComment = false;
    }

    void Parse_DefLump_Context_LineComment()
    {
        console.printf("Context Line Comment");
        // Check that going to the next line will not go beyond the file
        if (file.Line + 1 < file.Lines())
        {
            reader = 0;
            file.Line++;
        }
        else // It will so just end - hopefully sucessfully!
            t = T_END;

        bStartComment = bStartLineComment = false;
    }

    void Parse_DefLump_Context_Word(string w)
    {
        console.printf("Context Word");
        int ws = reader;
        int lineCheck = file.GetEOB(reader, w);
        if (lineCheck != -1)
            ztag.name = file.PeekFor(ws, reader - ws - 1);
        else
            t = stringToErrorCheck("OPENSTR");

        console.printf(string.format("ZTag is named: %s, reader was at: %d, reader is now at: %d", ztag.name, ws, reader));
        //bFirstQuote = false;
    }

    void DefLump_ErrorOutput()
    {
        switch (t)
        {
            default:
            case T_IDKWHAT:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, contains an unidentified error, starting at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(), t, file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_OPENCOMMENT:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, contains an unclosed block comment, starting at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(), t,  file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_INVALIDCHAR:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, invalid character detected! Last known valid data started at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(), t,  file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_OPENSTRING:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, unclosed string found! Last known valid data started at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(), t,  file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_UNEXPECTEDCODE:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, read unexpected character %s! Last known valid data started at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(), t,  file.LumpNumber, e, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
        }

        defParseFails++;
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

        // Initialize internals
        defParseFails = 0;
        ZeroContexts();

        // Ok, read ZMLDEFS lumps into file streams
        Generate_DefStreams();
        console.printf(string.Format("\t\t\cdZML successfully read \cy%d \cdtag definition lumps into file streams!\n\t\t\t\t\cc- This means the ZMLDEFS files are in a parse-able format, it does not mean they are valid.\n\n", defStreams.Size()));
        // Assuming that there are now file streams, try to make the tag lists
        Parse_DefLumps();
        // Well, no, something was wrong - it got handled but bitch and moan anyway
        if (defParseFails > 0)
            console.printf(string.Format("\n\t\t\ciZML failed to parse \cg%d \citag definition lumps!\n\t\t\t\t\cc- This means ZML encountered a problem with the file%s and stopped trying to create usable data from %s. Reported errors need fixed.\n\n", defParseFails, (defParseFails > 1 ? "s" : ""), (defParseFails > 1 ? "them" : "it")));
        // Nevermind, yay!  We win!
        else
            console.printf(string.format("\n\t\t\cyZML successfully parsed \cx%d \cyZMLDEFS lumps into \cx%d \cyZML tags!\n\n", defStreams.Size(), taglist.Size()));
    }

    enum ZMLINFO
    {
        CODE_HELP,
        CODE_ERROR_IDKWHAT,
        CODE_ERROR_OPENCOMMENT,

        CODE_BADADVICE,
    };

    ZMLINFO stringToInfoToken(string e)
    {
        if (e ~== "help")
            return CODE_HELP;
        if (e ~== "idkwhat")
            return CODE_ERROR_IDKWHAT;
        if (e ~== "opencomment")
            return CODE_ERROR_OPENCOMMENT;

        return CODE_BADADVICE;
    }

    /*
        Users can query ZML for information on errors.
    
    */
    override void NetworkProcess(ConsoleEvent e)
    {

    }

    /* - END OF METHODS - */
}

