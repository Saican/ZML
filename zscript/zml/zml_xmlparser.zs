/*

    What: Z-xtensible Markup Language XML Parser
    Who: Sarah Blackburn
    When: 05/03/22

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
            array<DefToken> parseList;
            if (Sanitize_StreamComments(TranslationStreams[i]) ?
                (Check_StreamContinuity(TranslationStreams[i]) ? 
                    Tokenize(TranslationStreams[i], parseList) :
                    false) :
                false)
                Parse(TranslationStreams[i], parseList, Seed);
        }

        int defStreamSize = Generate_DefinitionStreams(Seed);
        for (int i = 0; i < defStreamSize; i++)
        {
            array<DefToken> parseList;
            if (Sanitize_StreamComments(DefinitionStreams[i]) ?
                (Check_StreamContinuity(DefinitionStreams[i]) ? 
                    Tokenize(DefinitionStreams[i], parseList) :
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

    private bool Check_StreamContinuity(in out FileStream file)
    {
        // A few syntax chars can be reliably 
        // checked for by just counting them,
        // while others have variable uses
        int qc = 0,     // Quote count
            ltc = 0,    // Less than count
            gtc = 0;    // Greater than count
        while (file.StreamIndex() < file.StreamLength())
        {
            string c;
            int b;
            [c, b] = file.PeekToB();
            if (file.IsCodeChar(b, XMLCharSet))
            {
                switch (b)
                {
                    case CHAR_ID_DOUBLEQUOTE: qc++; break;
                    case CHAR_ID_LESSTHAN: ltc++; break;
                    case CHAR_ID_GREATERTHAN: gtc++; break;
                }
            }
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
            for (int i = 0; i < file.Lines(); i++)
            {
                int lltc = 0,
                    lgtc = 0;       
                for (int j = 0; j < file.LineLengthAt(i); j++)
                {
                    if (file.ByteAt(i, j) == CHAR_ID_LESSTHAN)
                        lltc++;
                    else if (file.ByteAt(i, j) == CHAR_ID_GREATERTHAN)
                        lgtc++;
                }

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

        return true;
    }

    private bool Tokenize(in out FileStream file, in out array<DefToken> parseList)
    {
        return true;
    }

    private void Parse(in out FileStream file, in out array<DefToken> parseList, in out ZMLSeed Seed)
    {}

    /* - END OF METHODS - */    
}