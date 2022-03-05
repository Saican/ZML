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

    /* 
        Reads each def lump into the defStreams array - without hashing files this function would cause duplicates!
        I seriously do not know why, and neither does anyone else apparently!  I asked!
        https://forum.zdoom.org/viewtopic.php?f=122&t=74720
    */
    void Generate_DefStreams(int l = 0)
    {
        do
        {
            // Read the lump into a string - there should be the base ZMLDEFS in the ZML package
            string rl = Wads.ReadLump(Wads.FindLump("zmldefs", l));
            // HaveStream returns bool, int
            bool hs;
            int ds;
            // Check if the lump has already been read - hs will be false if not, and ds will be the index in the file stream array if true
            [hs, ds] = HaveStream(FileStream.GetLumpHash(rl));
            if (!hs)
                defStreams.Push(new("FileStream").Init(rl, l));
            else
                console.printf(string.Format("\t\t\ciZML Warning! \ccNo big deal, but tried to read the same lump twice! Original lump # \ci%d\cc, duplicate lump # \ci%d", defStreams[ds].LumpNumber, l));
            // Iterate l and check if FindLump returns -1 - this seems to be where I get the duplicate.
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
        T_KEY_PHRASE,
        T_KEY_LIST,
        T_KEY_FLAG,

        // Special Characters - context establishing tokens
        T_SPECIALCHAR_DOUBLEQUOTE,
        T_SPECIALCHAR_COMMA,
        T_SPECIALCHAR_OPENBRACE,
        T_SPECIALCHAR_CLOSEBRACE,
        T_SPECIALCHAR_SEMICOLON,
        T_SPECIALCHAR_BACKSLASH,
        T_SPECIALCHAR_ASTERISK,

        // Context verification - this means what was received is unknown, 
        // so what happens next depends on the established context.
        T_WORD_CHAR,

        // These are errors
        T_IDKWHAT = -1,
        T_IDKWHAT_OPENCOMMENT = -2,
        T_IDKWHAT_INVALIDCHAR = -3,
        T_IDKWHAT_OPENSTRING = -4,
        T_IDKWHAT_UNEXPECTEDCODE = -5,
    };

    LTOKEN stringToToken(string e)
    {
        // Keywords
        if (e ~== "tag")
            return T_KEY_PHRASE;
        if (e ~== "attributes")
            return T_KEY_LIST;
        if (e ~== "addtype" || e ~== "overwrite" || e ~== "obeyincoming")
            return T_KEY_FLAG;

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
            
        return T_WORD_CHAR;
    }

    string tokenToString(LTOKEN t)
    {
        // Lexer Signals
        if (t == T_END)
            return "T_END";
        if (t == T_MORE)
            return "T_MORE";

        // Keywords
        if (t == T_KEY_PHRASE)
            return "T_KEY_PHRASE";
        if (t == T_KEY_LIST)
            return "T_KEY_LIST";
        if (t == T_KEY_FLAG)
            return "T_KEY_FLAG";

        // Special Characters - context establishing tokens
        if (t == T_SPECIALCHAR_DOUBLEQUOTE)
            return "T_SPECIALCHAR_DOUBLEQUOTE";
        if (t == T_SPECIALCHAR_COMMA)
            return "T_SPECIALCHAR_COMMA";
        if (t == T_SPECIALCHAR_OPENBRACE)
            return "T_SPECIALCHAR_OPENBRACE";
        if (t == T_SPECIALCHAR_CLOSEBRACE)
            return "T_SPECIALCHAR_CLOSEBRACE";
        if (t == T_SPECIALCHAR_SEMICOLON)
            return "T_SPECIALCHAR_SEMICOLON";
        if (t == T_SPECIALCHAR_BACKSLASH)
            return "T_SPECIALCHAR_BACKSLASH";
        if (t == T_SPECIALCHAR_ASTERISK)
            return "T_SPECIALCHAR_ASTERISK";

        if (t == T_WORD_CHAR)
            return "T_WORD_CHAR";

        // These are errors
        if (t == T_IDKWHAT)
            return "T_IDKWHAT";
        if (t == T_IDKWHAT_OPENCOMMENT)
            return "T_IDKWHAT_OPENCOMMENT";
        if (t == T_IDKWHAT_INVALIDCHAR)
            return "T_IDKWHAT_INVALIDCHAR";
        if (t == T_IDKWHAT_OPENSTRING)
            return "T_IDKWHAT_OPENSTRING";
        if (t == T_IDKWHAT_UNEXPECTEDCODE)
            return "T_IDKWHAT_UNEXPECTEDCODE";

        return "UNKNOWN TOKEN!!!!";
    }

    /*
        Returns boolean, checks if given string is a code character
    */
    bool IsCodeChar(string c)
    {
        if (c.Length() == 1)
        {
            int b = c.ByteAt(0);
            if (b == 34 || b == 44 || b == 123 || b == 125 || b == 59 || b == 47 || b == 42)
                return true;
        }

        return false;
    }

    /*
        Returns boolean, checks if the given string is alphanumeric
    */
    bool IsAlphaNum(string c)
    {
        if (c.Length() == 1)
        {
            int b = c.ByteAt(0);
            if ((b > 47 && b < 58) || (b > 64 && b < 91) || (b > 96 && b < 123))
                return true;
        }

        return false;
    }

    LTOKEN stringToErrorCheck(string e)
    {
        if (e ~== "OPENC")
            return T_IDKWHAT_OPENCOMMENT;
        if (e ~== "INVLDC")
            return T_IDKWHAT_INVALIDCHAR;
        if (e ~== "OPENSTR")
            return T_IDKWHAT_OPENSTRING;
        else
        {
            if (IsCodeChar(e))
                return T_IDKWHAT_UNEXPECTEDCODE;
            else if (IsAlphaNum(e))
                return T_IDKWHAT_INVALIDCHAR;
        }

        return T_IDKWHAT;
    }

    string errorToString(LTOKEN t)
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


    array<ZMLTag> taglist;

    /*
        These bools establish contexts
    */
    bool bKeyPhrase,
        bKeyList,
        bKeyFlag, 
    
        bStartComment,
        bStartLineComment,
        bStartBlockComment,

        bGetTagName,
        bGetAttributeName,
        bGetType,

        bHaveTagName,
        bHaveAttributeName,
        bHaveType,
        
        bFirstQuote,
        bLastQuote,
        bComma,
        bEOB,
        bOpenBlock,
        bOpenList,
        bCloseBlock,
        bCloseList;

    void NoContext()
    {
        bKeyPhrase = false;
        bKeyList = false;
        bKeyFlag = false;

        bStartComment = false;
        bStartLineComment = false;
        bStartBlockComment = false;

        bGetTagName = false;
        bGetAttributeName = false;
        bGetType = false;

        bHaveTagName = false;
        bHaveAttributeName = false;
        bHaveType = false;

        bFirstQuote = false;
        bLastQuote = false;
        bComma = false;
        bEOB = false;
        bOpenBlock = false;
        bOpenList = false;
        bCloseBlock = false;
        bCloseList = false;
    } 

    void Parse_DefLumps()
    {
        // Loop through each file stream
        for (int i = 0; i < defStreams.Size(); i++)
        {
            FileStream file = defStreams[i];
            string e = "";
            LTOKEN t = 1;
            ZMLTag ztag = null;
            ZMLElement zatt = null;
            NoContext();

            console.printf(string.Format("\n\n\cxPARSING LUMP# \cy%d\cx, HASH: \cy%d", file.LumpNumber, file.LumpHash));

            // This checks if the entire stream has been read
            while (file.StreamIndex() < file.StreamLength && t > 0)
            {
                // Get something from the stream
                e.AppendFormat("%s", file.PeekTo());
                // Attempt to create a token with it - the default is CHAR
                t = stringToToken(e);
                console.printf(string.Format("\cfLexing\cc - Contents of e: \cy%s\cc, resultant token: \cy%s\cc(\cx%d\cc)", e, tokenToString(t), t));

                // Establish syntax context
                Parse_DefLump_Contexualizer(file, e, t);
                // Valid token and we don't need more stream, so decide what to do with the context
                if (t > T_END && t != T_WORD_CHAR)
                {
                    Parse_DefLump_Context_Tasker(file, e, t, ztag, zatt);
                    e = "";
                }
            }
        }
    }

    void Parse_DefLump_Contexualizer(out FileStream file, string e, out LTOKEN t)
    {
        switch (t)
        {
            // Keywords
            case T_KEY_PHRASE:
                if (!bKeyPhrase)
                    bKeyPhrase = true;
                break;
            case T_KEY_LIST:
                if (bKeyPhrase)
                    bKeyList = true;
                break;
            case T_KEY_FLAG:
                if (bKeyPhrase)
                    bKeyFlag = true;
                break;

            /* 
                Context: Opening or closing of a word 
            */
            case T_SPECIALCHAR_DOUBLEQUOTE:
                if (bKeyPhrase || bKeyList)
                {
                    if (bFirstQuote)
                    {
                        bLastQuote = true;
                        console.printf("This is the last quote");
                    }
                    else if (bKeyPhrase && !bKeyList ? 
                                (!bHaveTagName || (bHaveTagName && bComma && !bHaveType)) : 
                                (!bHaveAttributeName || (bHaveAttributeName && bComma && !bHaveType)))
                    {
                        console.printf("This is the first quote");
                        bFirstQuote = true;
                    }
                    else
                    {
                        // Missing quote error
                    }
                }
                break;

            /* 
                Context : Separator of words 
            */
            case T_SPECIALCHAR_COMMA:
                if ((bKeyPhrase || bKeyList) && 
                    ((bFirstQuote && bLastQuote) && (bHaveTagName || bHaveAttributeName)))
                {
                        bComma = true;
                        bFirstQuote = bLastQuote = false;
                }
                else
                {
                    // Unexpect char error
                }
                break;

            /*
                Context: Opening of list
            */
            case T_SPECIALCHAR_OPENBRACE:
                if (bKeyPhrase && !bEOB && !bKeyList)
                    bOpenBlock = true;  
                else if (bKeyPhrase && !bEOB && bOpenBlock && bKeyList)
                    bOpenList = true;
                break;

            /*
                Context: Closing of list
            */
            case T_SPECIALCHAR_CLOSEBRACE:
                if (bKeyPhrase && !bEOB && bOpenBlock && (bKeyList ? bOpenList && bCloseList : false))
                    bCloseBlock = true;
                else if (bKeyPhrase && !bEOB && bOpenBlock && bKeyList && bOpenList)
                    bCloseList = true;
                break;

            /*
                Context: End of block
            */
            case T_SPECIALCHAR_SEMICOLON:
                if ((bKeyPhrase && bHaveTagName && bHaveType && !bOpenBlock) ||
                    (bKeyPhrase && !bEOB && bKeyList && bOpenList && bHaveAttributeName && bHaveType) ||
                    (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyFlag))
                    bEOB = true;
                else
                {
                    // Unexpected char error
                }
                break;

            /*
                Context: Comment
            */
            case T_SPECIALCHAR_BACKSLASH:
                if (bStartComment)
                    bStartLineComment = true;
                else if (file.Peek().ByteAt(0) == 42 || file.Peek().ByteAt(0) == 47)
                    bStartComment = true;
                else
                {
                    // Unexpected char error
                }
                break;

            /*
                Context: Block comment
            */
            case T_SPECIALCHAR_ASTERISK:
                if (bStartComment)
                    bStartBlockComment = true;
                else
                {
                    // Unexpected char error
                }
                break;

            /*
                Context: none/variable
                Verify that character belongs to established context
            */
            default:
            case T_WORD_CHAR:
                console.printf(string.format("\cpContextualizer\cc - Character encountered: %s, verify context.", e));
                
                break;                 
        }
    }

    void Parse_DefLump_Context_Tasker(out FileStream file, string e, out LTOKEN t, out ZMLTag ztag, out ZMLElement zatt)
    {
        // Block Comment
        if (bStartComment && bStartBlockComment)
            t = Parse_DefLump_Context_BlockComment(file);
        
        // Line Comment
        if (bStartComment && bStartLineComment)
            t = Parse_DefLump_Context_LineComment(file);

        // Create Tag
        if (bKeyPhrase && !ztag)
            ztag = new("ZMLTag").Init("zml_empty", "t_none");

        // Assign name
        if (bKeyPhrase && (ztag ? ztag.Empty() : false) && bFirstQuote && !bLastQuote)
        {
            console.Printf("Assigning name to tag");
            t = Parse_DefLump_Context_Word(file, ztag.name, "\"");
            if (t)
                bHaveTagName = true;
        }

        // Assign tag type
        if (bKeyPhrase && !bKeyList && bHaveTagName && bComma && bFirstQuote && !bLastQuote)
        {
            console.printf("Assigning type to tag");
            string ts;
            t = Parse_DefLump_Context_Word(file, ts, "\"");
            if (t)
            {
                ztag.type = ztag.GetType(ts);
                bHaveType = true;
            }
        }

        // Flag detection
        if (bKeyPhrase && bHaveTagName && bOpenBlock && !bEOB && (ztag ? (ztag.handling == ztag.HF_strict) : false) && bKeyFlag)
        {
            console.printf(string.format("ZTag will have flag assigned: %s", e));
            ztag.handling = ztag.stringToHFlag(e);
        }
        else if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyFlag && bEOB)
            bKeyFlag = bEOB = false;


        // Attribute names
        if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && bOpenList && bFirstQuote && !bLastQuote && !zatt)
        {
            zatt = new("ZMLElement").Init("zml_empty", "t_none");
            t = Parse_DefLump_Context_Word(file, zatt.name, "\"");
            if (t)
                bHaveAttributeName = true;
            console.printf(string.format("\cgOMG attributes have names! It'll be named: %s", zatt.name));
        }

        // Attribute type
        if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && bOpenList && bHaveAttributeName && bComma && bFirstQuote && !bLastQuote)
        {
            string ts;
            t = Parse_DefLump_Context_Word(file, ts, "\"");
            if (t)
            {
                zatt.type = zatt.GetType(ts);
                bHaveType = true;
            }
            console.printf(string.format("Assigning type to attribute"));
        }
        else if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && bOpenList && bComma && bFirstQuote && bLastQuote && bEOB)
        {
            ztag.attributes.Push(zatt);
            zatt = null;
            bHaveAttributeName = bHaveType = bComma = bFirstQuote = bLastQuote = bEOB = false;
        }

        // Tag Definition Termination
        if ((bKeyPhrase && bHaveTagName && bOpenBlock & bCloseBlock) || 
            (bKeyPhrase && bHaveTagName && bEOB))
        {
            console.printf(string.format("\cxTag, %s, was terminated! Has %d attributes!", ztag.name, ztag.attributes.Size()));
            taglist.Push(ztag);
            ztag = null;
            NoContext();
        }
        // Open block
        else if (bKeyPhrase && bHaveTagName && bComma && bFirstQuote && bHaveType && bLastQuote && bOpenBlock && !bKeyList)
        {
            console.printf("\cgTag opens up for attributes and flags");
            bComma = bFirstQuote = bHaveType = bLastQuote = false;
        }
    }

    /*
        Tokens are turned into "contexts",
        which is a fancy way of saying a bunch of
        booleans get switched on or off.

        The result of how those bools are set
        determines what each Contextulizer does.
    
    */
    LTOKEN Parse_DefLump_Context_BlockComment(out FileStream file)
    {
        console.printf("\ctParse\cc - Context Block Comment");
        // PeekEnd will search for the specified closing tag, setting reader in the process.
        // The return is the line to move to, however it will return -1 if nothing is found,
        // so we need to check it before setting file.Line.
        int nextLine = file.PeekEnd("*/");
        if (nextLine != -1)
            file.Line = nextLine;
        else
            return stringToErrorCheck("OPENC");

        bStartComment = bStartBlockComment = false;
        return 1;
    }

    LTOKEN Parse_DefLump_Context_LineComment(out FileStream file)
    {
        console.printf("\ctParse\cc - Context Line Comment");
        // Check that going to the next line will not go beyond the file
        if (file.Line + 1 < file.Lines())
        {
            file.Head = 0;
            file.Line++;
        }
        else // It will so just end - hopefully sucessfully!
            return 0;

        bStartComment = bStartLineComment = false;
        return 1;
    }

    LTOKEN Parse_DefLump_Context_Word(out FileStream file, out string word, string w)
    {
        console.printf("\ctParse\cc - Context Word");
        int ws = file.Head;
        int nextLine = file.PeekEnd(w);
        if (nextLine != -1)
            word = file.PeekFor(ws, (file.Head != 0 ? file.Head : file.Stream[file.Line].Length) - ws - 1);
        else
            return stringToErrorCheck("OPENSTR");

        if (file.Head != 0)
            file.Head -= 1;
        else // We do not move lines just because Head is 0, we need to go back and pick up the last quote if it's there.
            file.Head = ws + word.Length();

        console.printf(string.format("\ctParse\cc - Context Word - The word is: %s, Head was at: %d, Head is now at: %d%s", word, ws, file.Head, (file.Head == 0 ? string.Format(", moved lines, now on Line: %d", file.Line) : "")));
        return 1;
    }

    /*void DefLump_ErrorOutput(LTOKEN t, FileStream file, string e)
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
            case T_IDKWHAT_INVALIDCHAR:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, invalid character detected! Last known valid data started at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(t), t,  file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_OPENSTRING:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, unclosed string found! Last known valid data started at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(t), t,  file.LumpNumber, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
            case T_IDKWHAT_UNEXPECTEDCODE:
                console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump #\ci%d\cg, read unexpected character %s! Last known valid data started at line # \cii:%d\cg(\cyf:%d\cg)!\n\t\t\tLine contents: \cc%s", 
                    errorToString(t), t,  file.LumpNumber, e, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));
                break;
        }

        defParseFails++;
    }*/

    override void OnRegister()
    {
        // This mess creates the nice greeting ZML sends to the console.
        ZMLVersion = "0.1";
        string greeting = "Greetings! I am the Z-xtensible Markup Language Parser Event System, ";
        string vers = "version: ";
        int greetlen = string.Format("%s%s%s", greeting, vers, ZMLVersion).Length();
        string fullGreeting = string.Format("\n\n\cx%s\cc%s\cy%s\n\cx", greeting, vers, ZMLVersion);
        for (int i = 0; i < greetLen; i++)
            fullGreeting.AppendFormat("%s", "-");
        console.printf(fullGreeting);

        // Initialize internals
        defParseFails = 0;
        NoContext();

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
        {
            console.printf(string.format("\n\t\t\cyZML successfully parsed \cx%d \cyZMLDEFS lumps into \cx%d \cyZML tags!\n\n", defStreams.Size(), taglist.Size()));

            for (int i = 0; i < taglist.Size(); i++)
            {
                string al = " -- Tag contains attributes: ";
                for (int j = 0; j < taglist[i].attributes.Size(); j++)
                    al.AppendFormat("%s (type:%d), ", taglist[i].attributes[j].name, taglist[i].attributes[j].type);

                console.printf(string.Format("Tag is named (type%d): %s%s", taglist[i].type, taglist[i].name, taglist[i].attributes.Size() > 0 ? al : ""));
            }
        }
    }

    /* - END OF METHODS - */
}

