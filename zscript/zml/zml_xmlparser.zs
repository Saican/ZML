/*

    What: Z-xtensible Markup Language XML Parser
    Who: Sarah Blackburn
    When: 05/03/22

    Note that because a LOT of the groundwork for
    this code was done in the tag parser and the
    file stream, the comments may be a bit lacking
    here.  Please refer to the tag parser for more
    detailed documentation of the inner workings,
    as both parsers are very similar in function.

*/


class ZXMLParser
{
    const CHAR_ID_EXCLAMATION = 33;
    const CHAR_ID_DOUBLEQUOTE = 34;
    const CHAR_ID_HYPHEN = 45;
    const CHAR_ID_PERIOD = 46;
    const CHAR_ID_BACKSLASH = 47;
    const CHAR_ID_COLON = 58;
    const CHAR_ID_LESSTHAN = 60;
    const CHAR_ID_EQUAL = 61;
    const CHAR_ID_GREATERTHAN = 62;
    const CHAR_ID_UNDERSCORE = 95;

    ZMLCharset XMLCharSet;
    private void makeCharset()
    {
        XMLCharSet.CodeChars.Push(CHAR_ID_EXCLAMATION);
        XMLCharSet.CodeChars.Push(CHAR_ID_DOUBLEQUOTE);
        XMLCharSet.CodeChars.Push(CHAR_ID_HYPHEN);
        XMLCharSet.CodeChars.Push(CHAR_ID_PERIOD);
        XMLCharSet.CodeChars.Push(CHAR_ID_BACKSLASH);
        XMLCharSet.CodeChars.Push(CHAR_ID_COLON);
        XMLCharSet.CodeChars.Push(CHAR_ID_LESSTHAN);
        XMLCharSet.CodeChars.Push(CHAR_ID_EQUAL);
        XMLCharSet.CodeChars.Push(CHAR_ID_GREATERTHAN);
        XMLCharSet.CodeChars.Push(CHAR_ID_UNDERSCORE);
    }

    array<FileStream> TranslationStreams;
    array<FileStream> DefinitionStreams;

    array<string> DefinitionNames;

    int TranslationParseErrorCount,
        DefinitionParseErrorCount;
    array<StreamError> TranslationParseErrorList;
    array<StreamError> DefinitionParseErrorList;

    ZMLNode XMLTree;

    /*
        Returns - through references - a collection of elements from the given file
    */
    clearscope void FindElements_InFile(string FileName, string Name, in ZMLNode Root, in out array<ZMLNode> Elements)
    {
        ZMLNode n = FindFile(FileName, Root);
        if (n)
            n.FindElements(Name, n.Children, Elements);
    }

    clearscope void FindElements(string Name, in ZMLNode Root, in out array<ZMLNode> Elements) 
    { 
        if (XmlTree) 
            XmlTree.FindElements(Name, Root, Elements); 
    }

    /*
        Returns the entire DOM of the given file name.
        Function is recursive, you must supply the root node of the tree.
    */
    clearscope ZMLNode FindFile(string FileName, in ZMLNode Root)
    {
        if (Root.FileName == FileName)
            return Root;
        else if (Root.LeftSibling)
            return FindFile(FileName, Root.LeftSibling);
        else if (Root.RightSibling)
            return FindFile(FileName, Root.RightSibling);
        else
            return null;
    }

    ZXMLParser Init(in array<ZMLTag> TagList)
    {
        // This could have been done a bit cleaner, but 
        // character sets establish the language syntax.
        makeCharset();

        // XML Parsing basically happens twice.
        // The translation files themselves are xml, 
        // thus the whole thing needs ran on those 
        // files to create a list of actually useful files.
        TranslationParseErrorCount = 0;
        int transStreamSize = Generate_Streams();
        for (int i = 0; i < transStreamSize; i++)
        {
            array<XMLToken> parseList;
            if (Sanitize_StreamComments(TranslationStreams[i], TranslationParseErrorList) ?
                Check_StreamContinuity(TranslationStreams[i], TagList, TranslationParseErrorList) :
                false)
            {
                Tokenize(TranslationStreams[i], TagList, parseList);
                Parse(TranslationStreams[i], "zml", TagList, parseList, XMLTree, TranslationParseErrorList, TranslationParseErrorCount);
            }
            else
                TranslationParseErrorCount++;
        }

        DefinitionParseErrorCount = 0;
        int defStreamSize = Generate_DefinitionStreams();
        for (int i = 0; i < defStreamSize; i++)
        {
            array<XMLToken> parseList;
            if (Sanitize_StreamComments(DefinitionStreams[i], DefinitionParseErrorList) ?
                Check_StreamContinuity(DefinitionStreams[i], TagList, DefinitionParseErrorList) :
                false)
            {
                Tokenize(DefinitionStreams[i], TagList, parseList);
                Parse(DefinitionStreams[i], DefinitionNames[i], TagList, parseList, XMLTree, DefinitionParseErrorList, DefinitionParseErrorCount);
            }
            else
                DefinitionParseErrorCount++;
        }

        // Translation Error output
        if (TranslationParseErrorCount > 0)
            ErrorOutput(TranslationParseErrorList, TranslationParseErrorCount, "translation");

        // Definition Error output
        if (DefinitionParseErrorCount > 0)
            ErrorOutput(DefinitionParseErrorList, DefinitionParseErrorCount, "definition");

        XMLTree.NodeOut();

        return self;
    }

    private void ErrorOutput(in array<StreamError> ParseErrorList, int ParseErrorCount, string lumpType)
    {
        console.printf(string.Format("\n\t\t\ciZML failed to parse \cg%d \ciXML %s lumps!\n\t\t\t\t\cc- This means ZML encountered a problem with the file%s and stopped trying to create usable data from %s. Reported errors need fixed.\n\n", ParseErrorCount, lumpType, (ParseErrorCount > 1 ? "s" : ""), (ParseErrorCount > 1 ? "them" : "it")));

        for (int i = 0; i < ParseErrorList.Size(); i++)
        {
            StreamError error = ParseErrorList[i];
            console.printf(string.Format("\t\t\cgZML ERROR! Code: \cx%s_(%d) \cg- Lump: #\ci%d\cg, Lump Hash: \ci%d\cg, Message: \ci%s\cg\n\t\t\t - Contents of Lexer: \ci%s \cg- Last known valid data started at line: #\cii:%d\cg(\cyf:%d\cg)!\n\t\t\t - Line contents: \cc%s\n\n",
                error.CodeString, error.CodeId, error.LumpNumber, error.LumpHash, error.Message, error.StreamBufferContents, error.InternalLine, error.FileLine, error.FullLine));
        }
    }

    // Checks the array to see if any streams have the same hash
    private bool, int HaveStream(int h, in array<FileStream> Stream)
    {
        for (int i = 0; i < Stream.Size(); i++)
        {
            if (Stream[i].LumpHash == h)
                return true, i;
        }

        return false, -1;
    }

    /* 
        Reads each translation unit
    */
    private int Generate_Streams(int l = 0)
    {
        while ((l = Wads.FindLump("zml", l)) != -1)
        {
            ReadLump(l, TranslationStreams);
            l++;
        }

        console.printf(string.Format("\t\t\cdZML successfully read \cy%d \cdXML translation units into file streams!\n\t\t\t\t\cc- This means the files are in a parse-able format, it does not mean they are valid.\n\n", TranslationStreams.Size()));
        return TranslationStreams.Size();
    }

    /*
        Reads each definition
    */
    private int Generate_DefinitionStreams()
    {
        // Find all the <include> nodes
        array<ZMLNode> transList;
        FindElements("include", XMLTree, transList);
        for (int i = 0; i < transList.Size(); i++)
        {
            int l = Wads.CheckNumForFullName(transList[i].Data);
            if (l > -1)
            {
                DefinitionNames.Push(GetFileName(transList[i].Data));
                ReadLump(l, DefinitionStreams);
            }
        }
        console.printf(string.Format("\t\t\cdZML successfully read \cy%d \cdXML files into file streams!\n\t\t\t\t\cc- This means the files are in a parse-able format, it does not mean they are valid.\n\n", DefinitionStreams.Size()));
        return DefinitionStreams.Size();
    }

    /*
        Regardless of how we get a lump number,
        the whole process of reading the raw data
        is the same.
    */
    private void ReadLump(int l, in out array<FileStream> Stream)
    {
        string rl = Wads.ReadLump(l);
        bool hs;
        int ds;
        [hs, ds] = HaveStream(FileStream.GetLumpHash(rl), Stream);
        if (!hs)
            Stream.Push(new("FileStream").Init(rl, l));
        else
            console.printf(string.Format("\t\t\ciZML Warning! \ccNo big deal, but tried to read the same lump twice! Original lump # \ci%d\cc, duplicate lump # \ci%d", Stream[ds].LumpNumber, l));
    }

    /*
        Creates the filename
    */
    private string GetFileName(string p)
    {
        array<string> ps;
        p.Split(ps, "/");
        if (ps.Size() > 0)
        {
            array<string> fn;
            ps[ps.Size() - 1].Split(fn, ".");
            if (fn.Size() == 2)
                return fn[0];
        }

        return "";
    }

    private bool Sanitize_StreamComments(in out FileStream file, in out array<StreamError> ParseErrorList)
    {
        string e = "";
        while (file.StreamIndex() < file.StreamLength())
        {
            e.AppendFormat("%s", file.PeekTo());
            if (e ~== "<!--")
            {
                int ws = file.Head - 4;
                int nextLine = file.PeekEnd("-->", XMLCharSet);
                if (nextLine != -1)
                {
                    for (int i = file.Line; i <= nextLine; i++)
                    {
                        if (i == nextLine && file.Head == 0)
                            break;

                        int dt;
                        if (i == nextLine)
                            dt = file.Head;
                        else
                            dt = file.LineLengthAt(i);

                        for (int j = ws; j < dt; j++)
                            file.Stream[i].Chars.Delete(ws > 0 ? ws : 0);

                        file.Stream[i].Chars.ShrinkToFit();
                        ws = 0;
                    }

                    file.Line = nextLine;
                }
                else
                {
                    /* Throw open comment error */
                    ParseErrorList.Push(new("StreamError").Init(StreamError.ERROR_ID_OPENCOMMENT, 
                        file.LumpNumber, 
                        file.LumpHash, 
                        "UNCLOSED BLOCK COMMENT!", 
                        e, 
                        file.Line, 
                        file.Stream[file.Line].TrueLine, 
                        file.Stream[file.Line].FullLine()));
                    return false;    
                }

                e = "";
            }
        }

        for (int i = 0; i < file.Lines(); i++)
        {
            if (file.LineLengthAt(i) == 0)
                file.Stream.Delete(i--);
        }
        file.Stream.ShrinkToFit();
        file.Reset();
        file.StreamOut();
        return true;
    }  

    private bool Check_StreamContinuity(in out FileStream file, in array<ZMLTag> TagList, in out array<StreamError> ParseErrorList)
    {
        // A few syntax chars can be reliably 
        // checked for by just counting them,
        // while others have variable uses
        int qc = 0,     // Quote count
            ltc = 0,    // Less than count
            gtc = 0;    // Greater than count
        // This is a standard file loop that checks for the end of the file
        while (file.StreamIndex() < file.StreamLength())
        {
            // PeekToB returns string, bool
            string c; // we want the string for error output
            int b;
            // Either PeekTo function will move Line and Head, basically "turning the wheel"
            [c, b] = file.PeekToB();
            // Chcek if it's any of the syntax chars
            if (file.IsCodeChar(b, XMLCharSet))
            {
                // Whichever one it is, we're interested in these.
                switch (b)
                {
                    case CHAR_ID_DOUBLEQUOTE: qc++; break;
                    case CHAR_ID_LESSTHAN: ltc++; break;
                    case CHAR_ID_GREATERTHAN: gtc++; break;
                }
            }
            // Nope invalid char error
            else if (b != CHAR_ID_UNDERSCORE && !file.IsAlphaNum(b))
            {
                // Nope, add invalid char to error list 
                ParseErrorList.Push(new("StreamError").Init(StreamError.ERROR_ID_INVALIDCHAR, 
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

        // When done with a file, reset the file, downstream it's used again
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

                // If the number is more than zero and does not modulus to 0 that's our problem
                if (lqc > 0 && lqc % 2 != 0)
                {
                    // Add missing quote to error list
                    ParseErrorList.Push(new("StreamError").Init(StreamError.ERROR_ID_OPENSTRING, 
                        file.LumpNumber, 
                        file.LumpHash, 
                        "UNCLOSED STRING FOUND!", 
                        "N/A", 
                        i, 
                        file.Stream[i].TrueLine, 
                        file.Stream[i].FullLine()));
                    return false;
                }
            }
        }

        // Tag bracket count
        if (ltc != gtc)
        {
            // Go line by line
            for (int i = 0; i < file.Lines(); i++)
            {
                int lltc = 0,
                    lgtc = 0; 
                // Read each char and count the number of brackets      
                for (int j = 0; j < file.LineLengthAt(i); j++)
                {
                    if (file.ByteAt(i, j) == CHAR_ID_LESSTHAN)
                        lltc++;
                    else if (file.ByteAt(i, j) == CHAR_ID_GREATERTHAN)
                        lgtc++;
                }

                // They weren't equal on that line so that's the error line, the error code can figure out which error it is.
                if (lltc != lgtc)
                {
                    ParseErrorList.Push(new("StreamError").Init(lltc < lgtc ? StreamError.ERROR_ID_MISSINGLESSTHAN : StreamError.ERROR_ID_MISSINGGREATERTHAN, 
                        file.LumpNumber, 
                        file.LumpHash, 
                        lltc < lgtc ? "LESS THAN ( < ) MISSING! TAG UNCLOSED!" : "GREATER THAN ( > ) MISSING! TAG UNCLOSED!", 
                        "N/A", 
                        i, 
                        file.Stream[i].TrueLine, 
                        file.Stream[i].FullLine()));
                    return false;                  
                }
            }
        }

        // Terminated tags
        // Establish a buffer
        string e = "";
        // Setup a regular file read loop
        while(file.StreamIndex() < file.StreamLength())
        {
            // Fill the buffer, one char at a time
            e.AppendFormat("%s", file.PeekTo());

            // Check that the buffer contains a less than symbol and the next char is not a backslash
            if (e.ByteAt(0) == CHAR_ID_LESSTHAN && file.PeekB() != CHAR_ID_BACKSLASH)
            {
                string st = "",
                    ct = "";
                // Read the line from where Head is
                for (int i = file.Head; i < file.LineLength(); i++)
                {
                    if (file.ByteAt(file.Line, i) != CHAR_ID_GREATERTHAN)
                        st.AppendFormat("%s", file.CharAt(file.Line, i));
                    else
                    {
                        // Check if the temp buffer contains a tag name
                        for (int j = 0; j < TagList.Size(); j++)
                        {
                            // It does, format the closing tag
                            if (st == TagList[j].Name)
                            {
                                ct = string.Format("</%s>", TagList[j].Name);
                                break;
                            }
                        }

                        // It does not, likely the string contains the tag and attributes, time to slice and dice.
                        if (ct ~== "")
                        {
                            string as = "";
                            for (int j = 0; j < st.Length(); j++)
                            {
                                as.AppendFormat("%s", st.Mid(j, 1));
                                for (int k = 0; k < TagList.Size(); k++)
                                {
                                    if (as == TagList[k].Name && (TagList[k].Attributes.Size() == 0 ? as.Length() == TagList[k].Name.Length() : true))
                                    {
                                        ct = string.Format("</%s>", TagList[k].Name);
                                        break;
                                    }
                                }

                                if (ct != "")
                                    break;
                            }
                        }
                    }

                    if (ct != "")
                        break;
                }

                // Check we have a closing tag to look for
                if (ct != "")
                {
                    // Take advantage of how PeekEnd will just look for whatever now
                    int ws = file.Head;
                    int nextLine = file.PeekEnd(ct, XMLCharSet);
                    // If nextLine is -1 then the closing tag wasn't found
                    // So push unterminated tag error
                    if (nextLine == -1)
                    {
                        ParseErrorList.Push(new("StreamError").Init(StreamError.ERROR_ID_UNCLOSEDTAG, 
                            file.LumpNumber, 
                            file.LumpHash, 
                            "UNTERMINATED TAG DETECTED!", 
                            e, 
                            file.Line, 
                            file.Stream[file.Line].TrueLine, 
                            file.Stream[file.Line].FullLine()));
                        return false;  
                    }
                    // Good the closing tag was found, find the end of it and set head there.
                    // PeekEnd will have set head to who knows what, we need to pick up from
                    // end of the opening tag, there might be another tag right behind it.
                    else
                    {
                        for (int i = ws; i < file.LineLength(); i++)
                        {
                            if (file.ByteAt(file.Line, i) == CHAR_ID_GREATERTHAN)
                            {
                                file.Head = i;
                                break;
                            }
                        }
                    }
                }
                // Nope throw unknown xml identifier
                else
                {
                    ParseErrorList.Push(new("StreamError").Init(StreamError.ERROR_ID_UNKNOWN_XML_IDENTIFIER,
                    file.LumpNumber,
                    file.LumpHash,
                    "UNKNOWN XML IDENTIFIER (TAG) DETECTED!",
                    st,
                    file.Line,
                    file.Stream[file.Line].TrueLine,
                    file.Stream[file.Line].FullLine()));
                return false;   
                }   
            }
            // I feel like we do a lot of buffer purging
            e = "";
        }
        // What you supposed to do after messing with a file?  That's right!  Reset it!
        file.Reset();

        // Attributes - check that tags with attributes have their attributes spelled right
        e = ""; // Reuse e since it's scoped outside loops
        // Setup another read loop
        while (file.StreamIndex() < file.StreamLength())
        {
            // Fill the buffer
            e.AppendFormat("%s", file.PeekTo());
            // Check for a tag bracket and that the next char isn't a backslash
            if (e.ByteAt(0) == CHAR_ID_LESSTHAN && file.PeekB() != CHAR_ID_BACKSLASH)
            {
                // Set up temp buffers and info
                string st = "",     // Starting tag buffer
                    at;             // Attribute buffer
                bool ga = false;    // Got attribute
                int nh = 0;         // New Head
                // Read through the rest of the line
                for (int i = file.Head; i < file.LineLength(); i++)
                {
                    // Store tag chars in the temp buffer
                    st.AppendFormat("%s", file.CharAt(file.Line, i));
                    // Ok read through the tags and see if the buffer is a tag
                    for (int j = 0; j < TagList.Size(); j++)
                    {
                        // It is and it has attributes - yay...
                        if (st == TagList[j].Name && TagList[j].Attributes.Size() > 0 && file.ByteAt(file.Line, i + 1) != CHAR_ID_GREATERTHAN)
                        {
                            at = "";
                            // Read through the line again - luckily we just keep picking up where we left off
                            for (int k = i + 1; k < file.LineLength(); k++)
                            {
                                // More temp buffering
                                at.AppendFormat("%s", file.CharAt(file.Line, k));
                                // Ok this time compare the temp buffer to the attribute list
                                for (int m = 0; m < TagList[j].Attributes.Size(); m++)
                                {
                                    // And there is it, actually valid, took i, j, k, and m to get here!
                                    if (at == TagList[j].Attributes[m].Name)
                                    {
                                        ga = true;
                                        nh = k + 1;
                                        break;
                                    }
                                }

                                // ga is right lol, get out of the loop
                                if (ga)
                                    break;
                            }
                        }
                        // Ok its still a valid tag so we can jump over it
                        else if (st == TagList[j].Name)
                        {
                            ga = true;
                            nh = i + 1;
                        }

                        // Gotta scream a few times to get out of all the loops
                        if (ga)
                            break;
                    }

                    // One more time
                    if (ga)
                        break;
                }

                // Ok, we screamed there's a valid attribute enough to move to the end of the tag
                if (ga)
                {
                    for (int i = nh; i < file.LineLength(); i++)
                    {
                        if (file.ByteAt(file.Line, i) == CHAR_ID_GREATERTHAN)
                        {
                            file.Head = i;
                            break;
                        }
                    }
                }
                // All that work should result in some real screaming, errors!
                else
                {
                    ParseErrorList.Push(new("StreamError").Init(StreamError.ERROR_ID_UNKNOWN_XML_ATTRIBUTE,
                        file.LumpNumber,
                        file.LumpHash,
                        "UNKNOWN XML ATTRIBUTE DETECTED!",
                        at,
                        file.Line,
                        file.Stream[file.Line].TrueLine,
                        file.Stream[file.Line].FullLine()));
                    return false;                           
                }      
            }
            // Purge the buffer
            e = "";
        }
        // So guess what, reset the file
        file.Reset();
        // Holy crap we got here?  Return true before something else makes it return false!
        return true;
    }

    /*
        Tokenizing and Parsing are going to be the hardest
        50 feet to run aren't they?

        Ok, xml describes a tree structure.
        Going up, everything is a child.
        Going down, everything is root, aka a parent.
        It looks backwards in the file, further into the
        structure is further up the tree.
    */
    private void Tokenize(in out FileStream file, in array<ZMLTag> TagList, in out array<XMLToken> parseList)
    {
        console.printf("\cf\t - XML Tokenizing...");
        string e = "";
        while (file.StreamIndex() < file.StreamLength())
        {
            e.AppendFormat("%s", file.PeekTo());
            // Opening of tag
            if (e.ByteAt(0) == CHAR_ID_LESSTHAN && file.PeekB() != CHAR_ID_BACKSLASH)
            {
                // Create internal string buffer
                string st = "";

                int td = -1,            // This will be the index of the tag in the list
                    tl = file.Line,     // Record the line the tag was on
                    ts = file.Head,     // The start of the tag is wherever head is now
                    te = 0;             // The end can be 0 until we find it
                // Read the line from where Head is
                for (int i = file.Head; i < file.LineLength(); i++)
                {
                    // Append chars to the temp buffer and then search the tag list each time to see if we have a tag
                    if (file.ByteAt(file.Line, i) != CHAR_ID_GREATERTHAN)
                        st.AppendFormat("%s", file.CharAt(file.Line, i));
                    else
                    {
                        // Check if the temp buffer contains a tag name
                        for (int j = 0; j < TagList.Size(); j++)
                        {
                            // It does
                            if (st == TagList[j].Name)
                            {
                                td = j;         // store the index
                                te = i - 1;     // i should still be on the last character of the tag name
                                break;
                            }
                        }

                        // No it doesn't - that's probably because of attributes
                        if (td == -1)
                        {
                            string as = "";
                            for (int j = 0; j < st.Length(); j++)
                            {
                                as.AppendFormat("%s", st.Mid(j, 1));
                                for (int k = 0; k < TagList.Size(); k++)
                                {
                                    if (as == TagList[k].Name && (TagList[k].Attributes.Size() == 0 ? as.Length() == TagList[k].Name.Length() : true))
                                    {
                                        td = k;
                                        te = ts + as.Length() - 1;
                                        break;
                                    }
                                }

                                if (td > -1)
                                    break;
                            }
                        }
                    }

                    // Have a valid tag so goodbye this loop
                    if (td > -1)
                        break;
                }

                // SHOULD have a valid tag, but just in case check anyway
                if (td > -1)
                {
                    switch(TagList[td].Type)
                    {
                        // Roots contain other nodes - they will be terminated after child nodes
                        case ZMLTag.t_none:
                            // All we need to push is that it's a root token, and standard token info
                            parseList.Push(new("XMLToken").Init(XMLToken.WORD_ROOT, 
                                tl, ts, te - ts + 1));
                            break;
                        // Everything is a child and contains data - proceed with the stream witchcraft
                        default:
                            // Should not get t_unknown - that is checked for in the def parser
                            // So move things along to the end of the tag to begin picking up the data
                            int tse = file.PeekEnd(">", XMLCharSet),
                                dl = -1,    // Data line
                                ds = -1,    // Data start
                                de = 0;     // Data end
                            // Oh my, PeekEnd you dirty thing, you return -1 if you fail
                            if (tse > -1)
                            {
                                dl = tse;
                                ds = file.Head;
                            }

                            // Right, got the data, get the terminator
                            string ct = string.Format("</%s>", TagList[td].Name);
                            // Yep, PeekEnd again, that function is just so darn handy
                            int tee = file.PeekEnd(ct, XMLCharSet);
                            // SHOULD not return -1, but check anyway
                            if (tee > -1)
                            {
                                // This means the terminator is on its own line
                                if (tee - 1 != dl)
                                    de = file.Stream[dl].Length() - 1;
                                // It's on the same line as everything else
                                else
                                    de = file.Stream[dl].Length() - TagList[td].Name.Length() - 4; // there are three chars in the terminator tag, plus one for the index

                                // We need to pick up the next node or whatever
                                file.Line = tee;
                            }

                            // Got everything for the node token
                            parseList.Push(new("XMLToken").Init(XMLToken.WORD_NODE,
                                tl, ts, te - ts + 1,
                                dl, ds, de - ds + 1));

                            // Ok, manually terminate the tag
                            int xl = -1,    // Terminator line
                                xs = -1,    // Terminator start
                                xe = 0;     // Terminator end - seeing a pattern yet?
                            // Do the same check when figuring out where the data ends
                            // This means the terminator is on its own line - perfectly valid XML
                            if (tee - 1 != dl)
                            {
                                xl = tee - 1;
                                xs = 2;
                                xe = file.Stream[xl].Length() - 2;
                            }
                            // It's on the same line as everything else
                            else
                            {
                                xl = dl;
                                xs = file.Stream[xl].Length() - TagList[td].Name.Length() - 1;
                                xe = file.Stream[xl].Length() - 2;
                            }
                            // That's it - a terminator stores in the tag members
                            parseList.Push(new("XMLToken").Init(XMLToken.WORD_TERMINATE,
                                xl, xs, xe - xs + 1));
                            break;
                    }
                }
            }
            // All other terminators should be root terminators.
            else if (e.ByteAt(0) == CHAR_ID_LESSTHAN && file.PeekB() == CHAR_ID_BACKSLASH)
                parseList.Push(new("XMLToken").Init(XMLToken.WORD_TERMINATE, 
                    file.Line, 2, file.Stream[file.Line].Length() - 3));

            // Oh hey, it's a buffer needing purged
            e = "";
        }

        // Not really needed at this point but just good manners
        file.Reset();
        // If in doubt uncomment this
        TokenListOut(file, parseList);
    }

    /*
        Outputs the contents of the Token List for debugging purposes
    */
    private void TokenListOut(in FileStream file, in array<XmlToken> tokens)
    {
        console.printf(string.Format("Token List contains %d XML tokens.  Contents:", tokens.Size()));
        for (int i = 0; i < tokens.Size(); i++)
        {
            console.printf(string.format("Token #%d, word is: #:%d(s:%s), found on line: i:%d(f:%d), tag starts at: %d, tag length of: %d, resultant tag: %s,\n\tcontains data, found on line: i:%d(f:%d), data starts at: %d, data length of: %d, resultant data: %s", 
                i, 
                tokens[i].t, 
                XMLToken.TokenToString(tokens[i].t), 
                tokens[i].tagLine, 
                file.Stream[tokens[i].tagLine].TrueLine, 
                tokens[i].tagStart, 
                tokens[i].tagLength,
                tokens[i].tagLength > 0 ? file.Stream[tokens[i].tagLine].Mid(tokens[i].tagStart, tokens[i].tagLength) : "empty",
                tokens[i].dataLine,
                file.Stream[tokens[i].dataLine].TrueLine,
                tokens[i].dataStart,
                tokens[i].dataLength,
                tokens[i].dataLength > 0 ? file.Stream[tokens[i].dataLine].Mid(tokens[i].dataStart, tokens[i].dataLength) : "empty"));
        }
    }

    /*
        Take everything that came before it.
        Turn it into the XML tree.
        Finally.
    */
    private void Parse(in out FileStream file, string fileName, 
        in array<ZMLTag> TagList, 
        in out array<XMLToken> parseList, 
        in out ZMLNode Root, 
        in out array<StreamError> ParseErrorList, 
        in out int ParseErrorCount)
    {
        if (parseList.Size() > 0)
        {
            console.printf("Yay tokens and a seed, lets grow a tree!");

            ZMLNode r = null;
            for (int i = 0; i < parseList.Size(); i++)
            {
                switch(parseList[i].t)
                {
                    // Create a node that contains other nodes
                    case XMLToken.WORD_ROOT:
                        // We do not have an internal root node
                        if (!r)
                        {
                            // We do have a root, we can insert on it
                            if (Root)
                            {
                                console.printf("Inserting on root");
                                r = Root.Insert(Root,
                                        file.Stream[parseList[i].tagLine].Mid(parseList[i].tagStart, parseList[i].tagLength),
                                        fileName,
                                        "");
                            }
                            // No root either, so make a root
                            else
                            {
                                console.printf("Making new root");
                                r = Root = new("ZMLNode").Init(file.Stream[parseList[i].tagLine].Mid(parseList[i].tagStart, parseList[i].tagLength),
                                        fileName,
                                        "");
                            }
                        }
                        // We do have a root, so this needs to be a child node, check if we have children and insert on that tree
                        else if (r.Children)
                            r = r.Children.Insert(r.Children,
                                    file.Stream[parseList[i].tagLine].Mid(parseList[i].tagStart, parseList[i].tagLength),
                                    fileName,
                                    "");
                        // Nope, first child
                        else
                            r = r.Children = new("ZMLNode").Init(file.Stream[parseList[i].tagLine].Mid(parseList[i].tagStart, parseList[i].tagLength),
                                    fileName,
                                    "");
                        break;
                    // Create a node that will contain data
                    case XMLToken.WORD_NODE:
                        // The last and most problematic error - nodes outside of roots - I may fix for this to save processing
                        // But I can already forsee it being its own clusterfuck continuity check addon.
                        //
                        // So we do have an interal root
                        if (r)
                        {
                            // And that internal root has children, so insert into that tree
                            if(r.Children)
                                r.Children.Insert(r.Children, 
                                    file.Stream[parseList[i].tagLine].Mid(parseList[i].tagStart, parseList[i].tagLength),
                                    fileName,
                                    file.Stream[parseList[i].dataLine].Mid(parseList[i].dataStart, parseList[i].dataLength));
                            // First child on that tree
                            else
                                r.Children = new("ZMLNode").Init(file.Stream[parseList[i].tagLine].Mid(parseList[i].tagStart, parseList[i].tagLength),
                                    fileName,
                                    file.Stream[parseList[i].dataLine].Mid(parseList[i].dataStart, parseList[i].dataLength));
                        }
                        // Rar - luckily this is handled fairly gracefully, DeleteNode can be called on the tree itself
                        // to just get rid of this entire thing.  Additional continuity checking would save the time getting here.
                        else
                        {
                            XMLTree.DeleteNode(FindFile(fileName, XMLTree), FindFile(fileName, XMLTree).Weight);
                            ParseErrorList.Push(new("StreamError").Init(StreamError.ERROR_ID_NODE_DISORDER,
                                file.LumpNumber,
                                file.LumpHash,
                                "CHILD NODE FOUND OUTSIDE ROOT! TREE WITH BROKEN LIMB! AMPUTATE!",
                                "N/A",
                                -1,
                                -1,
                                "N/A"));
                            ParseErrorCount++;                         
                            return;
                        }
                        break;
                    // Ok if it's a root terminator, we need to find it's parent and make that be r.
                    case XMLToken.WORD_TERMINATE:
                        string term = file.Stream[parseList[i].tagLine].Mid(parseList[i].tagStart, parseList[i].tagLength);
                        for (int j = 0; j < TagList.Size(); j++)
                        {
                            if (term == TagList[j].Name && TagList[j].Type == ZMLTag.t_none)
                            {} 
                        }
                        break;
                }
            }
        }
        // Empty file error, seriously, comment out the file in the translation files!
        // You'll save thousands of lines of code erroring on your commented file!
        // You think this high level scripting stuff isn't taxing on the system?
        else
        {
            ParseErrorList.Push(new("StreamError").Init(StreamError.ERROR_ID_EMPTYFILE,
                file.LumpNumber,
                file.LumpHash,
                "NOTHING TO PARSE, FILE IS EMPTY?!\n\t \ci- Please remove file from load order if everything is commented out,\n\t - you wasted A LOT of processing time getting to this error, thank you.",
                "N/A",
                -1,
                -1,
                "N/A"));
            ParseErrorCount++;         
        }
    }

    /* - END OF METHODS - */    
}