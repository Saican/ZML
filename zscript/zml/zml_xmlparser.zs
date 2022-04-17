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

    int TranslationParseErrorCount,
        DefinitionParseErrorCount;
    array<StreamError> ParseErrorList;

    ZXMLParser Init(in out actor a_Seed, in array<ZMLTag> TagList)
    {
        makeCharset();
        ZMLSeed Seed = ZMLSeed(a_Seed);
        // XML Parsing basically happens twice.
        // The translation files themselves are xml, 
        // thus the whole thing needs ran on those 
        // files to create a list of actually useful files.
        TranslationParseErrorCount = 0;
        int transStreamSize = Generate_Streams();
        for (int i = 0; i < transStreamSize; i++)
        {
            array<XMLToken> parseList;
            if (Sanitize_StreamComments(TranslationStreams[i]) ?
                (Check_StreamContinuity(TranslationStreams[i], TagList) ? 
                    Tokenize(TranslationStreams[i], TagList, parseList) :
                    false) :
                false)
                Parse(TranslationStreams[i], parseList, Seed);
        }

        int defStreamSize = Generate_DefinitionStreams(Seed);
        for (int i = 0; i < defStreamSize; i++)
        {
            array<XMLToken> parseList;
            if (Sanitize_StreamComments(DefinitionStreams[i]) ?
                (Check_StreamContinuity(DefinitionStreams[i], TagList) ? 
                    Tokenize(DefinitionStreams[i], TagList, parseList) :
                    false) :
                false)
                Parse(DefinitionStreams[i], parseList, Seed);
        }   

        return self;
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
    private int Generate_DefinitionStreams(in ZMLSeed Seed)
    {
        // Find all the nodes under the "zmltranslation" namespace
        array<ZMLNode> transList;
        Seed.FindElements("zmltranslation", transList);
        array<string> transPaths;
        for (int i = 0; i < transList.Size(); i++)
        {
            ZMLNode incl = transList[i].GetChild("include");
            if (incl)
                transPaths.Push(incl.Data);
        }

        for (int i = 0; i < transPaths.Size(); i++)
        {
            int l = Wads.CheckNumForFullName(transPaths[i]);
            if (l > -1)
                ReadLump(l, DefinitionStreams);
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

    private bool Sanitize_StreamComments(in out FileStream file)
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

    private bool Check_StreamContinuity(in out FileStream file, in array<ZMLTag> TagList)
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
                    st.AppendFormat("%s", file.CharAt(file.Line, i));
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
                        if (st == TagList[j].Name && TagList[j].Attributes.Size() > 0)
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
    private bool Tokenize(in out FileStream file, in array<ZMLTag> TagList, in out array<XMLToken> parseList)
    {
        console.printf("\cf\t - XML Tokenizing...");
        string e = "";
        while (file.StreamIndex() < file.StreamLength())
        {
            e.AppendFormat("%s", file.PeekTo());
            if (e.ByteAt(0) == CHAR_ID_LESSTHAN && file.PeekB() != CHAR_ID_BACKSLASH)
            {
                string st = "";
                bool vt = false;
                int td = -1;
                // Read the line from where Head is
                for (int i = file.Head; i < file.LineLength(); i++)
                {
                    st.AppendFormat("%s", file.CharAt(file.Line, i));
                    // Check if the temp buffer contains a tag name
                    for (int j = 0; j < TagList.Size(); j++)
                    {
                        // It does, store the index and get out of the loops
                        if (st == TagList[j].Name)
                        {
                            vt = true;
                            td = j;
                            break;
                        }
                    }

                    if (vt)
                        break;
                }

                // Have a valid tag
                if (vt)
                {
                    switch(TagList[td].Type)
                    {
                        case ZMLTag.t_none:
                            /* This is a root node, it contains other nodes in its children tree,
                                we need to store: 
                                that it is a root node,
                                what it is named - or the tag index,
                                the file name*/
                            break;
                        default:
                            /* Everything else are children nodes*/
                            break;
                    }
                }            
            }
            e = "";
        }
        return true;
    }

    private void Parse(in out FileStream file, in out array<XMLToken> parseList, in out ZMLSeed Seed)
    {}

    /* - END OF METHODS - */    
}