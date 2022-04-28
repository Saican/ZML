/*

    What: Z-xtensible Markup Language ZMLSeed Object Definition
    Who: Sarah Blackburn
    When: 05/02/22

*/


/* 

    The ZMLSeed is either spawned by the EventHandler or placed by a map author,
    with the latter option existing to apply settings.

    The ZMLSeed is the API that is used to access the XML Tree.
*/
class ZMLSeed : actor
{
    default
    {
        //$Category ZML
        height 1;
        radius 1;
    }

    // This - as the class name implies - is the XML parser.
    // The XML tree is in the parser, because of access reasons.
    ZXMLParser ZML;

    override void PostBeginPlay()
    {
        ZML = new("ZXMLParser").Init(new("ZMLTagParser").Init().TagList);
        super.PostBeginPlay();
    }

    /*
        ZML API Wrappers for accessing the tree
    */
    clearscope void FindElements_InFile(string FileName, string Name, in out array<ZMLNode> Elements)
    {
        ZML.FindElements_InFile(FileName, Name, ZML.XMLTree, Elements);
    }

    clearscope void FindElements(string Name, in out array<ZMLNode> Elements)
    {
        ZML.FindElements(Name, ZML.XMLTree, Elements);
    }

    clearscope ZMLNode FindFile(string FileName)
    {
        return ZML.FindFile(FileName, ZML.XMLTree);
    }

    states
    {
        spawn:
            ZMLS A -1;
            wait;
    }
}

/*

    The ZMLWeed is placed by map authors to block the parser from activating.

*/
class ZMLWeed : actor
{
    default
    {
        //$Category ZML
        height 1;
        radius 1;
    }

    states
    {
        spawn:
            ZMLW A -1;
            wait;
    }
}

