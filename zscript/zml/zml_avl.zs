/*

    What: Z-xtensible Markup Language AVL Tree Definition
    Who: Sarah Blackburn
    When: 05/02/22

    Credit to the author on this site: https://www.guru99.com/avl-tree.html#12
    The code was copied and modified for ZScript.  Thank you!  I never quite
    wrapped my head around these things!

*/


class ZMLNode
{
    ZMLNode Children,
        LeftSibling,
        RightSibling;

    int Height,             // AVL balance value
        Weight;             // This gives the tree something to compare against

    string FileName,        // Name of the file the node came from - this may repeat  
        Name,               // Tag name - may also repeat
        Data;               // No generic types in ZScript, so API functions will do casting,
                            // or users may do so themselves.  ToBool is unique to the API though.

    clearscope void NodeOut()
    {
        console.printf(string.format("ZMLNode, Name: %s, from file: %s, contains data: %s\n\tnode height: %d, node weight: %d\n\tnode has children: %s, root child name: %s\n\tnode has left sibling: %s, left sibling name: %s\n\tnode has right sibling: %s, right sibling name: %s\n\n",
            Name, FileName, Data,
            Height, Weight,
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

    ZMLNode GetChild(string n)
    { return null; }

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

    ZMLNode Init(string Name, string FileName, string Data) 
    { 
        self.Children = self.LeftSibling = self.RightSibling = null; 
        self.Height = 0;
        self.Name = Name;
        self.FileName = FileName;
        self.Data = Data;
        self.Weight = Hash(string.Format("%s%s%s", FileName, Name, Data), Random());
        return self;
    }

    int calc_Height(ZMLNode p)
    {
        if (p.LeftSibling && p.RightSibling)
        {
            if (p.LeftSibling.Height < p.RightSibling.Height)
                return p.RightSibling.Height + 1;
            else
                return p.LeftSibling.Height + 1;
        }
        else if (p.LeftSibling && !p.RightSibling)
            return p.LeftSibling.Height + 1;
        else if (!p.LeftSibling && p.RightSibling)
            return p.RightSibling.Height + 1;

        return 0;
    }

    int getBalance(ZMLNode n)
    {
        if (n.LeftSibling && n.RightSibling)
            return n.LeftSibling.Height - n.RightSibling.Height; 
        else if (n.LeftSibling && !n.RightSibling)
            return n.LeftSibling.Height; 
        else if (!n.LeftSibling && n.RightSibling )
            return -n.RightSibling.Height;

        return 0;
    }

    ZMLNode llrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        p = n;
        tp = p.LeftSibling;

        p.LeftSibling = tp.RightSibling;
        tp.RightSibling = p;

        return tp; 
    }

    ZMLNode rrrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        p = n;
        tp = p.RightSibling;

        p.RightSibling = tp.LeftSibling;
        tp.LeftSibling = p;

        return tp; 
    }

    ZMLNode rlrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        ZMLNode tp2;
        p = n;
        tp = p.RightSibling;
        tp2 = p.RightSibling.LeftSibling;

        p.RightSibling = tp2.LeftSibling;
        tp.LeftSibling = tp2.RightSibling;
        tp2.LeftSibling = p;
        tp2.RightSibling = tp; 
        
        return tp2; 
    }

    ZMLNode lrrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        ZMLNode tp2;
        p = n;
        tp = p.LeftSibling;
        tp2 = p.LeftSibling.RightSibling;

        p.LeftSibling = tp2.RightSibling;
        tp.RightSibling = tp2.LeftSibling;
        tp2.RightSibling = p;
        tp2.LeftSibling = tp; 
        
        return tp2; 
    }

    ZMLNode insert(ZMLNode r, string Name, string FileName, string Data)
    {      
        if (!r)
        {
            ZMLNode n;
            n = new("ZMLNode").Init(Name, FileName, Data);
            r = n;
            r.Height = 1; 
            return r;             
        }
        else
        {
            if (Weight < r.Weight)
                r.LeftSibling = insert(r.LeftSibling, Name, FileName, Data);
            else
                r.RightSibling = insert(r.RightSibling, Name, FileName, Data);
        }

        r.Height = calc_Height(r);

        if (getBalance(r) == 2 && getBalance(r.LeftSibling) == 1)
            r = llrotation(r);
        else if (getBalance(r) == -2 && getBalance(r.RightSibling) == -1)
            r = rrrotation(r);
        else if (getBalance(r) == -2 && getBalance(r.RightSibling) == 1)
            r = rlrotation(r);
        else if (getBalance(r) == 2 && getBalance(r.LeftSibling) == -1)
            r = lrrotation(r);

        return r;
    }
 
    ZMLNode deleteNode(ZMLNode p, int Weight)
    {
        if (!p.LeftSibling && !p.RightSibling)
        {
            if (p == self.Children)
                self.Children = null;
            return null;
        }

        ZMLNode t;
        ZMLNode q;
        if (p.Weight < Weight)
            p.RightSibling = deleteNode(p.RightSibling, Weight);
        else if (p.Weight > Weight)
            p.LeftSibling = deleteNode(p.LeftSibling, Weight);
        else
        {
            if (p.LeftSibling)
            {
                q = inpre(p.LeftSibling);
                p.Name = q.Name;
                p.Data = q.Data;
                p.Children = q.Children;
                p.Weight = q.Weight;
                p.LeftSibling = deleteNode(p.LeftSibling, q.Weight);
            }
            else
            {
                q = insuc(p.RightSibling);
                p.Name = q.Name;
                p.Data = q.Data;
                p.Children = q.Children;
                p.Weight = q.Weight;
                p.RightSibling = deleteNode(p.RightSibling, q.Weight);
            }
        }

        if (getBalance(p) == 2 && getBalance(p.LeftSibling) == 1)
            p = llrotation(p);
        else if (getBalance(p) == 2 && getBalance(p.LeftSibling) == -1)
            p = lrrotation(p);
        else if (getBalance(p) == 2 && getBalance(p.LeftSibling) == 0)
            p = llrotation(p);
        else if (getBalance(p) == -2 && getBalance(p.RightSibling) == -1)
            p = rrrotation(p);
        else if (getBalance(p) == -2 && getBalance(p.RightSibling) == 1)
            p = rlrotation(p);
        else if (getBalance(p) == -2 && getBalance(p.RightSibling) == 0)
            p = llrotation(p);

        return p;
    }
    
    ZMLNode inpre(ZMLNode p)
    {
        while (p.RightSibling)
            p = p.RightSibling;

        return p;    
    }

    ZMLNode insuc(ZMLNode p)
    {
        while(p.LeftSibling)
            p = p.LeftSibling;

        return p;    
    }

    /* - END OF METHODS - */
}