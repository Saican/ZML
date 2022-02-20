/*

    What: Z-xtensible Markup Language Error Definition
    Who: Sarah Blackburn
    When: 20/02/22

*/


class ZMLError
{
    int Token,
        ReadAt,
        LineLength,
        InternalLineNumber,
        ActualLineNumber;
    string Line;

    ZMLError Init(int Token, int ReadAt, int LineLength, int InternalLineNumber, int ActualLineNumber, string Line)
    {
        self.Token = Token;
        self.ReadAt = ReadAt;
        self.LineLength = LineLength;
        self.InternalLineNumber = InternalLineNumber;
        self.ActualLineNUmber = ActualLineNumber;
        self.Line = Line;
        return self;
    }
}