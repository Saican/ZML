/*
    What : ZML Parser Error Class Definition
    Who : Sarah Blackburn
    When : 27/03/2022

*/

class StreamError
{
    const ERROR_ID_IDKWHAT = -1;
    const ERROR_ID_OPENCOMMENT = -2;
    const ERROR_ID_INVALIDCHAR = -3;
    const ERROR_ID_OPENSTRING = -4;
    const ERROR_ID_UNEXPECTEDCODE = -5;
    const ERROR_ID_MISSINGCOMMA = -6;
    const ERROR_ID_MISSINGEOB = -7;
    const ERROR_ID_MISSINGOPENBRACE = -8;
    const ERROR_ID_MISSINGCLOSEBRACE = -9;
    const ERROR_ID_UNKNOWNIDENTIFIER = -10;

    int CodeId,
        LumpNumber,
        LumpHash,
        InternalLine,
        FileLine;

    string CodeString,
        Message,
        StreamBufferContents,
        FullLine;

    StreamError Init(int CodeId, int LumpNumber, int LumpHash, string Message, string StreamBufferContents, int InternalLine, int FileLine, string FullLine)
    {
        self.CodeId = CodeId;
        self.CodeString = errorToString(CodeId);
        self.LumpNumber = LumpNumber;
        self.LumpHash = LumpHash;
        self.Message = Message;
        self.StreamBufferContents = StreamBufferContents;
        self.InternalLine = InternalLine;
        self.FileLine = FileLine;
        self.FullLine = FullLine;
        return self;
    }

    private string errorToString(int t)
    {
        switch (t)
        {
            case ERROR_ID_OPENCOMMENT:          return "Cuban Bullfinch : OPEN_COMMENT";
            case ERROR_ID_INVALIDCHAR:          return "Brewer's Blackbird : INVALID_CHAR";
            case ERROR_ID_OPENSTRING:           return "Lark Bunting : OPEN_STRING";
            case ERROR_ID_UNEXPECTEDCODE:       return "Hooded Crow : UNEXPECTED_CODE";
            case ERROR_ID_MISSINGCOMMA:         return "Common Grackle : MISSING_COMMA";
            case ERROR_ID_MISSINGEOB:           return "Great Cormorant : MISSING_EOB";
            case ERROR_ID_MISSINGOPENBRACE:     return "Crested Myna : MISSING_OPEN_BRACE";
            case ERROR_ID_MISSINGCLOSEBRACE:    return "Black Pheobe : MISSING_CLOSE_BRACE";
            case ERROR_ID_UNKNOWNIDENTIFIER:    return "Bronzed Cowbird : UNKNOWN_IDENTIFIER";
            default:
            case ERROR_ID_IDKWHAT: return "Murder_of_Crows_IDKWHAT";
        }
    }

    /* - END OF METHODS - */
}