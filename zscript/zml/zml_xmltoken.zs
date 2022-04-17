/*

    What: Z-xtensible Markup Language XML Token Definition
    Who: Sarah Blackburn
    When: 16/04/22

*/

class XMLToken
{
    enum W_TOKEN
    {
        WORD_ROOT,
        WORD_NODE,
        WORD_TERMINATE,
        WORD_NONE,
    };

    W_TOKEN t;
    int line,
        start,
        length;

    static int StringToToken(string e)
    {
        return WORD_NONE;
    }

    static string TokenToString(int t)
    {
        switch (t)
        {
            default: return "WORD_NONE";
        }
    }

    XMLToken Init(int t, int line, int start = 0, int length = 0)
    {
        self.t = t;
        self.line = line;
        self.start = start;
        self.length = length;
        return self;
    }
}