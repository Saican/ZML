/*

    What: Z-xtensible Markup Language Binary Search Tree Definition
    Who: Sarah Blackburn
    When: 24/04/22

*/

class ZMLNode
{
    string FileName, Name, Data;

    int Weight,
        Seed;

    ZMLNode Children,
        LeftSibling,
        RightSibling;

    array<ZMLAttribute> Attributes;

    int Hash(string d, int r)
    {
        int a = 54059;
        int b = 76963;
        int c = 86969;
        int h = 37;
        for (int i = 0; i < d.Length(); i++)
            h = (h * a) ^ (d.ByteAt(i) * b);

        return h * r % c;
    }

    int InsertWeight(string f) { return Hash(string.Format("%sz%sm%sl", f, f, f), Seed); }

    ZMLNode Init(int Seed, string FileName, string Name, string Data)
    {
        self.FileName = FileName;
        self.Name = Name;
        self.Data = Data;
        self.Weight = Hash(string.Format("%sz%sm%sl", FileName, FileName, FileName), Seed);
        self.Seed = Seed;
        Children = LeftSibling = RightSibling = null;
        return self;
    }

    ZMLNode InsertNode(in out ZMLNode Tree, int Seed, string FileName, string Name, string Data)
    {
        if (!Tree)
        {
            Tree = new("ZMLNode").Init(Seed, FileName, Name, Data);
            return Tree;
        }
        else if (Tree.Weight > InsertWeight(FileName))
            return InsertNode(Tree.LeftSibling, Seed, FileName, Name, Data);
        else
            return InsertNode(Tree.RightSibling, Seed, FileName, Name, Data);
    }

    void Delete(ZMLNode Tree, string FileName)
    {
        if (Tree.Weight > InsertWeight(FileName))
            Delete(Tree.LeftSibling, FileName);
        else if (Tree.Weight < InsertWeight(FileName))
            Delete(Tree.RightSibling, FileName);
        else
            DeleteNode(Tree);
    }

    private void DeleteNode(in out ZMLNode Tree)
    {
        string d;
        ZMLNode tn = Tree;
        if (!Tree.LeftSibling)
            Tree = Tree.RightSibling;
        else if (!Tree.RightSibling)
            Tree = Tree.LeftSibling;
        else
        {
            GetPredecessor(Tree.LeftSibling);
            Tree.Data = d;
            Delete(Tree.LeftSibling, Tree.LeftSibling.FileName);
        }
    }

    private string GetPredecessor(in out ZMLNode Tree)
    {
        while (Tree.RightSibling)
            Tree = Tree.RightSibling;
        return Tree.Data;
    }

    clearscope void NodeOut()
    {
        console.printf(string.format("ZMLNode, Name: %s, from file: %s, contains data: %s\n\tnode weight: %d\n\tnode has children: %s, root child name: %s\n\tnode has left sibling: %s, left sibling name: %s\n\tnode has right sibling: %s, right sibling name: %s\n\n",
            Name, FileName, Data, Weight,
            Children ? "yes" : "no",
            Children ? Children.Name : "N/A",
            LeftSibling ? "yes" : "no",
            LeftSibling ? LeftSibling.Name : "N/A",
            RightSibling ? "yes" : "no",
            RightSibling ? RightSibling.Name : "N/A"));

        if (Children)
            Children.NodeOut();
        if (LeftSibling)
            LeftSibling.NodeOut();
        if (RightSibling)
            RightSibling.NodeOut();
    }

    clearscope void FindElements(string Name, in ZMLNode Root, in out array<ZMLNode> Elements)
    {
        if (Root.Name == Name)
            Elements.Push(Root);

        if (Root.Children)
            Root.FindElements(Name, Root.Children, Elements);

        if (Root.LeftSibling)
            Root.FindElements(Name, Root.LeftSibling, Elements);
        
        if (Root.RightSibling)
            Root.FindElements(Name, Root.RightSibling, Elements);
    }

    /* - END OF METHODS - */
}

class ZMLAttribute
{
    string Name, Value;

    ZMLAttribute Init(string Name, string Value)
    {
        self.Name = Name;
        self.Value = Value;
        return self;
    }
}