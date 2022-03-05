/*

    What: Z-xtensible Markup Language Element Defintion
    Who: Sarah Blackburn
    When: 19/02/22

*/


class ZMLElement
{
    enum NODETYPE
    {
        t_string,
        t_int,
        t_float,
        t_double,
        t_bool,
        t_none,
        t_unknown,
    };

    NODETYPE type;

    NODETYPE GetType(string e)
    {
        string el = e.MakeLower();
        if (el ~== "t_string")
            return t_string;
        if (el ~== "t_int")
            return t_int;
        if (el ~== "t_float")
            return t_float;
        if (el ~== "t_double")
            return t_double;
        if (el ~== "t_bool")
            return t_bool;
        if (el ~== "t_none")
            return t_none;
        else
            return t_unknown;
    }

    string name;
    bool Empty() { return (name ~== "zml_empty"); }

    ZMLElement Init(string name, string type)
    {
        self.name = name;
        self.type = GetType(type);
        return self;
    }
}


class ZMLTag : ZMLElement
{
    enum HFLAG
    {
        HF_strict,
        HF_addtype,
        HF_overwrite,
        HF_obeyincoming,
    };
    HFLAG handling;
    HFLAG stringToHFlag(string e)
    {
        if (e ~== "addtype")
            return HF_addtype;
        if (e ~== "overwrite")
            return HF_overwrite;
        if (e ~== "obeyincoming")
            return HF_obeyincoming;
        
        return HF_strict;
    }

    array<ZMLElement> attributes;

    ZMLTag Init(string name, string type) 
    {
        handling = HF_strict;
        return ZMLTag(super.Init(name, type)); 
    }
}

