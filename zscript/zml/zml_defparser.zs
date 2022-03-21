/*
    What : ZML Tag Definition (ZMLDEFS) Parser
    Who : Sarah Blackburn
    When : 19/03/2022

    Hey I added this to test if the Linux Script works or not!

*/

class ZML_DefParser
{
    const CHAR_ID_DOUBLEQUOTE = 34;
    const CHAR_ID_ASTERISK = 42;
    const CHAR_ID_COMMA = 44;
    const CHAR_ID_BACKSLASH = 47;
    const CHAR_ID_SEMICOLON = 59;
    const CHAR_ID_OPENBRACE = 123;
    const CHAR_ID_CLOSEBRACE = 125;

    array<FileStream> Streams;
    // Counts how many files failed to parse
    int defParseFails;

    ZML_DefParser Init()
    {
        // Initialize internals
        defParseFails = 0;
        int streamSize = Generate_Streams();
        for (int i = 0; i < streamSize; i++)
        {
            // Sanitize Comments
            Sanitize_StreamComments(Streams[i]);
            // Perfrom Continuity Check
            Check_StreamContinuity(Streams[i]);
            // Tokenize

            //Parse_DefLumps();
        }
        
        // Well, no, something was wrong - it got handled but bitch and moan anyway
        /*if (defParseFails > 0)
            console.printf(string.Format("\n\t\t\ciZML failed to parse \cg%d \citag definition lumps!\n\t\t\t\t\cc- This means ZML encountered a problem with the file%s and stopped trying to create usable data from %s. Reported errors need fixed.\n\n", defParseFails, (defParseFails > 1 ? "s" : ""), (defParseFails > 1 ? "them" : "it")));
        // Nevermind, yay!  We win!
        else
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
    private void Sanitize_StreamComments(in out FileStream file)
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
                    int ws = file.Head - 1;
                    int nextLine = file.PeekEnd("*/");
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
                    {/* Throw open comment error */}
                }
                // Line comment
                else if (file.PeekB() == CHAR_ID_BACKSLASH)
                {
                    int dt = file.LineLength();
                    for (int i = file.Head - 1; i < dt; i++)
                        file.Stream[file.Line].Chars.Delete(file.Head - 1);

                    file.Stream[file.Line].Chars.ShrinkToFit();
                    file.Line++;
                    file.Head = 0;
                }
                else
                {/* Throw unexpected character error */}
            }

            e = "";
        }

        // Remove empty lines from the stream
        for (int i = 0; i < file.Lines(); i++)
        {
            if (file.LineLengthAt(i) == 0)
                file.Stream.Delete(i--);
        }
        file.Stream.ShrinkToFit();
        file.Line = file.Head = 0;

        file.StreamOut();
    }

    /*
        Checks each file for continuity - this means quotes are closed, braces are closed,etc.  
        This does not check for line termination (semicolons); 
    */
    private void Check_StreamContinuity(in out FileStream file)
    {
        int b, 
            qc = 0,
            cc = 0, 
            obc = 0, 
            cbc = 0;
        while (file.StreamIndex() < file.StreamLength())
        {
            b = file.PeekTo().ByteAt(0);
            if (file.IsCodeChar(b))
            {
                switch (b)
                {
                    case CHAR_ID_DOUBLEQUOTE: qc++; break;
                    case CHAR_ID_COMMA: cc++ break;
                    case CHAR_ID_OPENBRACE: obc++; break;
                    case CHAR_ID_CLOSEBRACE: cbc++; break;
                }
            }
            else if (!file.IsAlphaNum(b))
            { /* Throw invalid char error */ }
        }

        // Quote count - should be 2 for each word, thus remainder should be 0
        if (qc % 2 != 0)
        { /* Figure out where, but throw missing quote error */ }

        // Comma count - should be 1 for every 4 quotes
        if (cc != qc / 4)
        { /* Figure out where, but throw missing comma error */ }

        // Open brace count - should be equal to close brace count
        if (obc < cbc)
        { /* Missing opening brace error */}
        // Close brace count - should be equal to open brace count
        else if (cbc < obc)
        { /* Missing closing brace error */ }
    }


    /* - END OF METHODS - */
}