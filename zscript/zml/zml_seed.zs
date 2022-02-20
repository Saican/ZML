/*

    What: Z-xtensible Markup Language ZMLSeed Object Definition
    Who: Sarah Blackburn
    When: 05/02/22

*/


/* 

    The ZMLSeed is either spawned by the EventHandler or placed by a map author,
    with the latter option existing to apply settings.

    The ZMLSeed is the API that is used to access the ZMLTree.
*/
class ZMLSeed : actor
{
    default
    {
        //$Category ZML
        height 1;
        radius 1;
    }

    ZMLTree ZTree;

    override void PostBeginPlay()
    {
        self.ZTree = new("ZMLTree").Init();
        super.PostBeginPlay();
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

