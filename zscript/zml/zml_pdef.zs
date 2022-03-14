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
        Reads each def lump into the defStreams array
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

        // These are errors
        T_IDKWHAT = -1,
        T_IDKWHAT_OPENCOMMENT = -2,
        T_IDKWHAT_INVALIDCHAR = -3,
        T_IDKWHAT_OPENSTRING = -4,
        T_IDKWHAT_UNEXPECTEDCODE = -5,
        T_IDKWHAT_MISSINGCOMMA = -6,
        T_IDKWHAT_MISSINGEOB = -7,
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
            
        return T_MORE;
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
        if (t == T_IDKWHAT_MISSINGCOMMA)
            return "T_IDKWHAT_MISSINGCOMMA";
        if (t == T_IDKWHAT_MISSINGEOB)
            return "T_IDKWHAT_MISSINGEOB";

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



    /*
        Public member.
        This array contains the resulting xml tag list.
    
    */
    array<ZMLTag> taglist;

    /*
        Called the "boolean flock",
        these establish context based
        on the given token during parse.
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

    /*
        This secondary flock
        creates "pre-contexts".
        That is, the parser can
        expect certain buffer contents
        and error check for that.
    */
    private bool bPreComma,
        bPreEOB,
        bPreOpenBlock,
        bPreOpenList,
        bPreCloseBlock,
        bPreCloseList;

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

        bPreComma = false;
        bPreEOB = false;
        bPreOpenBlock = false;
        bPreOpenList = false;
        bPreCloseBlock = false;
        bPreCloseList = false;
    }

    private bool AnyContext()
    {
        return (bKeyPhrase || bKeyList || bKeyFlag ||
            bStartComment || bStartLineComment || bStartBlockComment ||
            bGetTagName || bGetAttributeName || bGetType ||
            bHaveTagName || bHaveAttributeName || bHaveType ||
            bFirstQuote || bLastQuote || bComma || bEOB || bOpenBlock || bOpenList || bCloseBlock || bCloseList ||
            bPreComma || bPreEOB || bPreOpenBlock || bPreOpenList || bPreCloseBlock || bPreCloseList);
    } 

    private void Parse_DefLumps()
    {
        // Loop through each file stream
        for (int i = 0; i < defStreams.Size(); i++)
        {
            FileStream file = defStreams[i];    // The stream is referred to this way everywhere else, so...
            string e = "";                      // Lexer buffer - what string from the stream is shoved into
            LTOKEN t = 1;                       // Token - it's just a number so sometimes I treat it like one
            ZMLTag ztag = null;                 // ZMLTag reference
            ZMLElement zatt = null;             // ZMLElement reference
            NoContext();                        // Clear the flock

            console.printf(string.Format("\n\n\cxPARSING LUMP# \cy%d\cx, HASH: \cy%d\cx, CONTAINED IN LUMP: \cy%s", file.LumpNumber, file.LumpHash, Wads.GetLumpFullName(file.LumpNumber)));

            // This checks if the entire stream has been read
            while (file.StreamIndex() < file.StreamLength && t > 0)
            {
                // Get something from the stream
                e.AppendFormat("%s", file.PeekTo());
                // Attempt to create a token with it - the default is MORE
                t = stringToToken(e);
                console.printf(string.Format("\cfLexing\cc - Contents of e: \cy%s\cc, resultant token: \cy%s\cc(\cx%d\cc)", e, tokenToString(t), t));

                // Establish syntax context
                Parse_DefLump_Contexualizer(file, e, t);
                // Check the context status from the last loop - the tasker establishes what to expect
                Parse_DefLump_PreContext_Check(file, t);

                // Check what was produced from lexing
                if (t > T_END && t != T_MORE)
                {
                    // Do something from the context
                    Parse_DefLump_Context_Tasker(file, e, t, ztag, zatt);
                    // The lexer buffer needs cleared.
                    e = "";
                }
            }

            // Oh no! Errors!
            if (t < 0)
                DefLump_ErrorOutput(t, file, e);
        }
    }

    /*
        Takes the token and sets the boolean flock
    */
    private void Parse_DefLump_Contexualizer(in FileStream file, string e, LTOKEN t)
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
            // Context: Opening or closing of a word
            case T_SPECIALCHAR_DOUBLEQUOTE:
                if (bKeyPhrase || bKeyList)
                {
                    if (bFirstQuote)
                        bLastQuote = true;
                    else if (bKeyPhrase && !bKeyList ? 
                                (!bHaveTagName || (bHaveTagName && bComma && !bHaveType)) : 
                                (!bHaveAttributeName || (bHaveAttributeName && bComma && !bHaveType)))
                        bFirstQuote = true;
                }
                break;
            // Context : Separator of words
            case T_SPECIALCHAR_COMMA:
                if ((bKeyPhrase || bKeyList) && 
                    ((bFirstQuote && bLastQuote) && (bHaveTagName || bHaveAttributeName)))
                {
                        bComma = true;
                        bFirstQuote = bLastQuote = false;
                }
                break;
            // Context: Opening of list
            case T_SPECIALCHAR_OPENBRACE:
                if (bKeyPhrase && !bEOB && !bKeyList)
                    bOpenBlock = true;  
                else if (bKeyPhrase && !bEOB && bOpenBlock && bKeyList)
                    bOpenList = true;
                break;
            // Context: Closing of list
            case T_SPECIALCHAR_CLOSEBRACE:
                if (bKeyPhrase && !bEOB && bOpenBlock && (bKeyList ? bOpenList && bCloseList : false))
                    bCloseBlock = true;
                else if (bKeyPhrase && !bEOB && bOpenBlock && bKeyList && bOpenList)
                    bCloseList = true;
                break;
            // Context: End of block
            case T_SPECIALCHAR_SEMICOLON:
                bEOB = true;
                break;
            // Context: Comment
            case T_SPECIALCHAR_BACKSLASH:
                if (bStartComment)
                    bStartLineComment = true;
                else if (file.PeekB() == 42 || file.PeekB() == 47)
                    bStartComment = true;
                break;
            // Context: Block comment
            case T_SPECIALCHAR_ASTERISK:
                if (bStartComment)
                    bStartBlockComment = true;
                break;                
        }
    }

    /*
        If the given context is false, checks if the next character
        matches the given byte code.

        Returns true if: the context is false and the next character maches
    
    */
    private bool ContextPeek(in FileStream file, bool ctx, int b) 
    { 
        //console.printf(string.format("ctx: %d, b: %d, peek: %d, head: %d, line length: %d", ctx, b, file.PeekB(), file.Head, file.LineLength()));
        return (!ctx &&                                                                 // We should have no context
                    (file.StreamIndex() < file.StreamLength ?                           // Check if we've read the whole file
                        (file.Head < file.LineLength() ?                                // Check if we've read the whole line
                            file.PeekB() == b :                                         // If all of the above passes, does the next byte code match?
                            file.Line + 1 < file.Lines() ?                              // It did not, so can we check the next line?
                                file.Stream[file.Line + 1].Chars[0].ByteAt(0) == b :    // Apparently we can, so access down to the first char and repeat the check
                                false) :                                                // Out of lines - which probably means end of the the file too
                        false));                                                        // End of the file
    }

    /*
        Does some witchcraft with the flock and the stream 
        to error check before going to the tasker.
    
    */
    private void Parse_DefLump_PreContext_Check(in FileStream file, out LTOKEN t)
    {
        //console.printf("checking for missing commas");
        // Missing comma
        if (bKeyPhrase && !bKeyList ? 
                (bHaveTagName && bLastQuote && bPreComma && !ContextPeek(file, bComma, 44)) :
                (bHaveAttributeName && bLastQuote && bPreComma && !ContextPeek(file, bComma, 44)))
            t = T_IDKWHAT_MISSINGCOMMA;
        else if (t == T_SPECIALCHAR_COMMA && bPreComma)
            bPreComma = false;

        //console.printf("checking for missing eobs");
        // Missing EOB
        if (((bKeyPhrase && !bKeyList && bHaveTagName && bKeyFlag && bPreEOB && !bEOB) || // Flags
            (bKeyPhrase && !bKeyList && bHaveTagName && bHaveType && bLastQuote && bPreEOB && !ContextPeek(file, bOpenBlock, 123) && (bOpenBlock || bEOB ? false : !ContextPeek(file, bEOB, 59))) || // Tag termination
            (bKeyPhrase && bKeyList && bHaveAttributeName && bHaveType && bLastQuote && bPreEOB && (bEOB ? false : !ContextPeek(file, bEOB, 59))))) // Attribute termination
            t = T_IDKWHAT_MISSINGEOB;
        else if ((t == T_SPECIALCHAR_SEMICOLON || t == T_SPECIALCHAR_OPENBRACE) && bPreEOB)
            bPreEOB = false;
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
        C_ATTRIBUTE_START,
        C_ATTRIBUTE_NAME,
        C_ATTRIBUTE_TYPE,
        C_ATTRIBUTE_FINISH,
        C_TERMINATE_TAG,
        C_OPEN_BLOCK,
        C_NONE,
    };

    /*
        The flock is turned into a
        context token that allows
        the tasker to be a bit more
        organized.  This does mean
        the soup is just cooked
        someplace else.

        REMEMBER SARAH!!!!
        IT PROBABLY ISN'T WISE TO RELY ON ANY OF THE PRE CONTEXT FLOCK,
        UNLESS YOU'RE CHECKING THAT IT'S FALSE!!!!!

    */
    private LCONTEXT EvaluateContext(in ZMLTag ztag, in ZMLElement zatt)
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
        if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyFlag && !bPreEOB && !bEOB)
            return C_FLAG;
        else if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyFlag && bEOB)
            return C_CLOSE_FLAG;
        // Attribute list setup
        if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && !bPreOpenList && !bOpenList)
            return C_ATTRIBUTE_START;
        // Attribute names
        if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && bOpenList && bFirstQuote && !bLastQuote && !zatt)
            return C_ATTRIBUTE_NAME;
        // Attribute type
        if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && bOpenList && bHaveAttributeName && bComma && bFirstQuote && !bLastQuote)
            return C_ATTRIBUTE_TYPE;
        else if (bKeyPhrase && bHaveTagName && bOpenBlock && bKeyList && bOpenList && bComma && bFirstQuote && bLastQuote && bEOB)
            return C_ATTRIBUTE_FINISH;
        // Tag Definition Termination
        if ((bKeyPhrase && bHaveTagName && bOpenBlock & bCloseBlock) || 
            (bKeyPhrase && bHaveTagName && bEOB))
            return C_TERMINATE_TAG;
        // Open block
        else if (bKeyPhrase && bHaveTagName && bComma && bFirstQuote && bHaveType && bLastQuote && bOpenBlock && !bKeyList)
            return C_OPEN_BLOCK;

        return C_NONE;
    }

    /*
        Determines what to do based on EvaluateContext.
        This is the final step where the parser can
        finally do something with the contents of the lexer.
    */
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
                t = Parse_DefLump_Context_Word(file, ztag.name, "\"");
                if (t)
                    bHaveTagName = bPreComma = true;
                break;
            // Assign tag type
            case C_ASSIGN_TAG_TYPE:
                string tts;
                t = Parse_DefLump_Context_Word(file, tts, "\"");
                if (t)
                {
                    ztag.type = ztag.GetType(tts);
                    bHaveType = true;
                    bPreEOB = bPreOpenBlock = true;
                }
                break;
            // Flag detection
            case C_FLAG:
                ztag.handling = ztag.stringToHFlag(e);
                bPreEOB = true;
                break;
            // Flag termination
            case C_CLOSE_FLAG:
                bKeyFlag = bEOB = bPreEOB = false;
                break;
            // Begin Attribute List
            case C_ATTRIBUTE_START:
                bPreOpenList = true;
                console.printf("Set to open attribute list");
                break;
            // Attribute names
            case C_ATTRIBUTE_NAME:
                zatt = new("ZMLElement").Init("zml_empty", "t_none");
                t = Parse_DefLump_Context_Word(file, zatt.name, "\"");
                if (t)
                    bHaveAttributeName = bPreComma = true;
                break;
            // Attribute type
            case C_ATTRIBUTE_TYPE:
                string ats;
                t = Parse_DefLump_Context_Word(file, ats, "\"");
                console.printf("got attribute type");
                if (t)
                {
                    zatt.type = zatt.GetType(ats);
                    bHaveType = true;
                    bPreEOB = true;
                }
                break;
            // Attribute termination
            case C_ATTRIBUTE_FINISH:
                console.printf("finished attribute");
                ztag.attributes.Push(zatt);
                zatt = null;
                bHaveAttributeName = bHaveType = bComma = bFirstQuote = bLastQuote = bPreEOB = bEOB = false;
                break;
            // Tag Definition Termination
            case C_TERMINATE_TAG:
                console.printf(string.format("\cxTag, \cy%s\cx, was terminated! Has \cy%d \cxattributes!", ztag.name, ztag.attributes.Size()));
                taglist.Push(ztag);
                ztag = null;
                NoContext();
                break;
            // Open block
            case C_OPEN_BLOCK:
                console.printf(string.format("\cxTag, \cy%s\cx, opens up for attributes and flags!", ztag.name));
                bComma = bFirstQuote = bHaveType = bLastQuote = bPreEOB = false;
                break;
        }
    }

    /*
        These functions are just jobs.
        Oddly comments get the most special treatment,
        where most everything else goes through Context_Word.
    
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
            return T_IDKWHAT_OPENCOMMENT;

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
            word = file.PeekFor(ws, (file.Head != 0 ? file.Head : file.LineLength()) - ws - 1);
        else
            return T_IDKWHAT_OPENSTRING;

        if (file.Head != 0)
            file.Head -= 1;
        else // We do not move lines just because Head is 0, we need to go back and pick up the last quote if it's there.
            file.Head = ws + word.Length();

        console.printf(string.format("\ctParse\cc - Context Word - The word is: %s, Head was at: %d, Head is now at: %d%s", word, ws, file.Head, (file.Head == 0 ? string.Format(", moved lines, now on Line: %d", file.Line) : "")));
        return 1;
    }

    /*
        Produces the lovely error message
        when syntax errors are encountered.
    
    */
    void DefLump_ErrorOutput(LTOKEN t, FileStream file, string e)
    {
        string m = "";
        switch (t)
        {
            default:
            case T_IDKWHAT:
                m = "UNIDENTIFIED ERROR!";
                break;
            case T_IDKWHAT_OPENCOMMENT:
                m = "UNCLOSED BLOCK COMMENT!";
                break;
            case T_IDKWHAT_INVALIDCHAR:
                m = "INVALID CHARACTER DETECTED!";
                break;
            case T_IDKWHAT_OPENSTRING:
                m = "UNCLOSED STRING FOUND!";
                break;
            case T_IDKWHAT_UNEXPECTEDCODE:
                m = "UNEXPECTED CHARACTER READ!";
                break;
            case T_IDKWHAT_MISSINGCOMMA:
                m = "COMMA (,) MISSING BETWEEN NAME AND TYPE OF ELEMENT!";
                break;
            case T_IDKWHAT_MISSINGEOB:
                m = "END OF BLOCK (;) MISSING!";
        }

        console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump: #\ci%d\cg, Lump Hash: \ci%d\cg, Message: \ci%s\cg\n\t\t\t - Contents of Lexer: \ci%s \cg- Last known valid data started at line: #\cii:%d\cg(\cyf:%d\cg)!\n\t\t\t - Line contents: \cc%s",
            errorToString(t), t, file.LumpNumber, file.LumpHash, m, e, file.Line, file.Stream[file.Line].TrueLine, file.Stream[file.Line].FullLine()));

        defParseFails++;
    }

    private string errorToString(LTOKEN t)
    {
        switch (t)
        {
            case T_IDKWHAT_OPENCOMMENT: return "OPENCOMMENT";
            case T_IDKWHAT_INVALIDCHAR: return "INVALIDCHAR";
            case T_IDKWHAT_OPENSTRING: return "OPENSTRING";
            case T_IDKWHAT_UNEXPECTEDCODE: return "UNEXPECTEDCODE";
            case T_IDKWHAT_MISSINGCOMMA: return "MISSINGCOMMA";
            case T_IDKWHAT_MISSINGEOB : return "MISSINGEOB";
            default:
            case T_IDKWHAT: return "IDKWHAT";
        }
    }

    /* - END OF METHODS - */
}