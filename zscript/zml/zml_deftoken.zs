/*
    What : ZML Parser Def Token Definition
    Who : Sarah Blackburn
    When : 27/03/2022

*/


class DefToken
{
    enum W_TOKEN
    {
        WORD_TAG,
        WORD_ATTRIBUTE,
        WORD_NAME,
        WORD_TYPE,
        WORD_FLAG_ADDTYPE,
        WORD_FLAG_OVERWRITE,
        WORD_FLAG_OBEYINCOMING,
        WORD_NONE,
    };

    W_TOKEN t;
    int line,
        start,
        length; 

    static int StringToToken(string e)
    {
        if (e ~== "tag")
            return WORD_TAG;
        if (e ~== "attribute")
            return WORD_ATTRIBUTE;
        if (e ~== "addtype")
            return WORD_FLAG_ADDTYPE;
        if (e ~== "overwrite")
            return WORD_FLAG_OVERWRITE;
        if (e ~== "obeyincoming")
            return WORD_FLAG_OBEYINCOMING;

        return WORD_NONE;
    }

    DefToken Init(int t, int line, int start, int length)
    {
        self.t = t;
        self.line = line;
        self.start = start;
        self.length = length;
        return self;
    }
}