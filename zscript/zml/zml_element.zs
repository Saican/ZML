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

    ZMLElement Init(string name, string type)
    {
        self.name = name;
        self.type = GetType(type);
        return self;
    }
}


class ZMLTag : ZMLElement
{
    array<ZMLElement> attributes;

    ZMLTag Init(string name, string type) { return ZMLTag(super.Init(name, type)); }
}

