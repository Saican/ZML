/*

    What: Z-xtensible Markup Language Parser Event Handler
    Who: Sarah Blackburn
    When: 05/02/22

*/


class ZMLHandler : EventHandler
{
    string ZMLVersion;

    override void OnRegister()
    {
        // This mess creates the nice greeting ZML sends to the console.
        ZMLVersion = "0.1";
        string greeting = "Greetings! I am the Z-xtensible Markup Language Parser Event System, ";
        string vers = "version: ";
        int greetlen = string.Format("%s%s%s", greeting, vers, ZMLVersion).Length();
        string fullGreeting = string.Format("\n\n\cx%s\cc%s\cy%s\n\cx", greeting, vers, ZMLVersion);
        for (int i = 0; i < greetLen; i++)
            fullGreeting.AppendFormat("%s", "-");
        console.printf(fullGreeting);

        // Initialize internals
        ZML_DefParser tagParser = new("ZML_DefParser").Init();
    }

    /* - END OF METHODS - */
}

