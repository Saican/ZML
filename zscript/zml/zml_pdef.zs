/*

    What: Z-xtensible Markup Language Tag Definition Parser
    Who: Sarah Blackburn
    When: 05/03/22

*/


class Parser_ZMLTag
{
    Parser_ZMLTag Init()
    {
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

        return self;
    }

    // Contains the contents of each def lump, without whitespace
    array<FileStream> defStreams;
    // Counts how many files failed to parse
    int defParseFails;
    // Checks the array to see if any streams have the same hash
    private bool, int HaveStream(int h)
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
    private void Generate_DefStreams(int l = 0)
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
                defStreams.Push(new("FileStream").Init(rl, l));
            else
                console.printf(string.Format("\t\t\ciZML Warning! \ccNo big deal, but tried to read the same lump twice! Original lump # \ci%d\cc, duplicate lump # \ci%d", defStreams[ds].LumpNumber, l));

            l++;
        }
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

    private LTOKEN stringToToken(string e)
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

    private string tokenToString(LTOKEN t)
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
    private bool IsCodeChar(string c)
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
    private bool IsAlphaNum(string c)
    {
        if (c.Length() == 1)
        {
            int b = c.ByteAt(0);
            if ((b > 47 && b < 58) || (b > 64 && b < 91) || (b > 96 && b < 123))
                return true;
        }

        return false;
    }

    private LTOKEN stringToErrorCheck(string e)
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

    private string errorToString(LTOKEN t)
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
    private bool bKeyPhrase,
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

    private void NoContext()
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

    private void Parse_DefLumps()
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

            console.printf(string.Format("\n\n\cxPARSING LUMP# \cy%d\cx, HASH: \cy%d\cx, CONTAINED IN LUMP: \cy%s", file.LumpNumber, file.LumpHash, Wads.GetLumpFullName(file.LumpNumber)));

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

    private void Parse_DefLump_Contexualizer(out FileStream file, string e, out LTOKEN t)
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

    enum LCONTEXT
    {
        C_BLOCK_COMMENT,
        C_LINE_COMMENT,
        C_MAKE_TAG,
        C_ASSIGN_TAG_NAME,
        C_ASSIGN_TAG_TYPE,
        C_FLAG,
        C_CLOSE_FLAG,
        C_ATTRIBUTE_NAME,
        C_ATTRIBUTE_TYPE,
        C_FINISH_ATTRIBUTE,
        C_TERMINATE_TAG,
        C_OPEN_BLOCK,
        C_NONE,
    };

    private LCONTEXT EvaluateContext(out ZMLTag ztag, out ZMLElement zatt)
    {
        // Block Comment
        if (bStartComment && bStartBlockComment)
            return C_BLOCK_COMMENT;
        // Line Comment
        if (bStartComment && bStartLineComment)
            return C_LINE_COMMENT;
        // Create Tag
        if (bKeyPhrase && !ztag)
            return C_MAKE_TAG;
        // Assign Tag Name
        if (bKeyPhrase && (ztag ? ztag.Empty() : false) && bFirstQuote && !bLastQuote) 
            return C_ASSIGN_TAG_NAME;
        // Assign Tag Type
        if (bKeyPhrase && !bKeyList && bHaveTagName && bComma && bFirstQuote && !bLastQuote)
            return C_ASSIGN_TAG_TYPE;
        // Flag Detection
        if (bKeyPhrase && !bKeyList && bHaveTagName && bComma && bFirstQuote && !bLastQuote)
            return C_FLAG;
        else if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyFlag && bEOB)
            return C_CLOSE_FLAG;
        // Attribute names
        if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && bOpenList && bFirstQuote && !bLastQuote && !zatt)
            return C_ATTRIBUTE_NAME;
        // Attribute type
        if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && bOpenList && bHaveAttributeName && bComma && bFirstQuote && !bLastQuote)
            return C_ATTRIBUTE_TYPE;
        else if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && bOpenList && bComma && bFirstQuote && bLastQuote && bEOB)
            return C_FINISH_ATTRIBUTE;
        // Tag Definition Termination
        if ((bKeyPhrase && bHaveTagName && bOpenBlock & bCloseBlock) || 
            (bKeyPhrase && bHaveTagName && bEOB))
            return C_TERMINATE_TAG;
        // Open block
        else if (bKeyPhrase && bHaveTagName && bComma && bFirstQuote && bHaveType && bLastQuote && bOpenBlock && !bKeyList)
            return C_OPEN_BLOCK;

        return C_NONE;
    }

    private void Parse_DefLump_Context_Tasker(out FileStream file, string e, out LTOKEN t, out ZMLTag ztag, out ZMLElement zatt)
    {
        switch (EvaluateContext(ztag, zatt))
        {
            // Block Comment
            case C_BLOCK_COMMENT:
                t = Parse_DefLump_Context_BlockComment(file);
                break;
            
            // Line Comment
            case C_LINE_COMMENT:
                t = Parse_DefLump_Context_LineComment(file);
                break;

            // Create Tag
            case C_MAKE_TAG:
                ztag = new("ZMLTag").Init("zml_empty", "t_none");
                break;

            // Assign name
            case C_ASSIGN_TAG_NAME:
                console.Printf("Assigning name to tag");
                t = Parse_DefLump_Context_Word(file, ztag.name, "\"");
                if (t)
                    bHaveTagName = true;
                break;

            // Assign tag type
            case C_ASSIGN_TAG_TYPE:
                console.printf("Assigning type to tag");
                string tts;
                t = Parse_DefLump_Context_Word(file, tts, "\"");
                if (t)
                {
                    ztag.type = ztag.GetType(tts);
                    bHaveType = true;
                }
                break;

            // Flag detection
            case C_FLAG:
                console.printf(string.format("ZTag will have flag assigned: %s", e));
                ztag.handling = ztag.stringToHFlag(e);
                break;
            case C_CLOSE_FLAG:
                bKeyFlag = bEOB = false;
                break;


            // Attribute names
            case C_ATTRIBUTE_NAME:
                zatt = new("ZMLElement").Init("zml_empty", "t_none");
                t = Parse_DefLump_Context_Word(file, zatt.name, "\"");
                if (t)
                    bHaveAttributeName = true;
                console.printf(string.format("\cgOMG attributes have names! It'll be named: %s", zatt.name));
                break;

            // Attribute type
            case C_ATTRIBUTE_TYPE:
                string ats;
                t = Parse_DefLump_Context_Word(file, ats, "\"");
                if (t)
                {
                    zatt.type = zatt.GetType(ats);
                    bHaveType = true;
                }
                console.printf(string.format("Assigning type to attribute"));
                break;
            case C_FINISH_ATTRIBUTE:
                ztag.attributes.Push(zatt);
                zatt = null;
                bHaveAttributeName = bHaveType = bComma = bFirstQuote = bLastQuote = bEOB = false;
                break;

            // Tag Definition Termination
            case C_TERMINATE_TAG:
                console.printf(string.format("\cxTag, %s, was terminated! Has %d attributes!", ztag.name, ztag.attributes.Size()));
                taglist.Push(ztag);
                ztag = null;
                NoContext();
                break;
            // Open block
            case C_OPEN_BLOCK:
                console.printf("\cgTag opens up for attributes and flags");
                bComma = bFirstQuote = bHaveType = bLastQuote = false;
                break;
        }
    }

    /*
        Tokens are turned into "contexts",
        which is a fancy way of saying a bunch of
        booleans get switched on or off.

        The result of how those bools are set
        determines what each Contextulizer does.
    
    */
    private LTOKEN Parse_DefLump_Context_BlockComment(out FileStream file)
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

    private LTOKEN Parse_DefLump_Context_LineComment(out FileStream file)
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

    private LTOKEN Parse_DefLump_Context_Word(out FileStream file, out string word, string w)
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

    /* - END OF METHODS - */
}