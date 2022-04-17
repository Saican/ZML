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
    ZMLNode Root,       // Children tree
        Left, Right;    // Sibling trees
    int Height,
        Weight;

    string Name,
        Data;

    ZMLNode GetChild(string n)
    { return null; }

    int Hash(string d)
    {
        int a = 54059;
        int b = 76963;
        int c = 86969;
        int h = 37;
        for (int i = 0; i < d.Length(); i++)
            h = (h * a) ^ (d.ByteAt(i) * b);

        return h % c;
    }

    ZMLNode Init(string Name, string FileName, string Data) 
    { 
        self.Root = self.Left = self.Right = null; 
        self.Height = 0;
        self.Name = Name;
        self.Data = Data;
        self.Weight = Hash(FileName);
        return self;
    }

    int calc_Height(ZMLNode p)
    {
        if (p.Left && p.Right)
        {
            if (p.Left.Height < p.Right.Height)
                return p.Right.Height + 1;
            else
                return p.Left.Height + 1;
        }
        else if (p.Left && !p.Right)
            return p.Left.Height + 1;
        else if (!p.Left && p.Right)
            return p.Right.Height + 1;

        return 0;
    }

    int getBalance(ZMLNode n)
    {
        if (n.Left && n.Right)
            return n.Left.Height - n.Right.Height; 
        else if (n.Left && !n.Right)
            return n.Left.Height; 
        else if (!n.Left && n.Right )
            return -n.Right.Height;

        return 0;
    }

    ZMLNode llrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        p = n;
        tp = p.Left;

        p.Left = tp.Right;
        tp.Right = p;

        return tp; 
    }


    ZMLNode rrrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        p = n;
        tp = p.Right;

        p.Right = tp.Left;
        tp.Left = p;

        return tp; 
    }


    ZMLNode rlrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        ZMLNode tp2;
        p = n;
        tp = p.Right;
        tp2 = p.Right.Left;

        p.Right = tp2.Left;
        tp.Left = tp2.Right;
        tp2.Left = p;
        tp2.Right = tp; 
        
        return tp2; 
    }

    ZMLNode lrrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        ZMLNode tp2;
        p = n;
        tp = p.Left;
        tp2 = p.Left.Right;

        p.Left = tp2.Right;
        tp.Right = tp2.Left;
        tp2.Right = p;
        tp2.Left = tp; 
        
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
                r.Left = insert(r.Left, Name, FileName, Data);
            else
                r.Right = insert(r.Right, Name, FileName, Data);
        }

        r.Height = calc_Height(r);

        if (getBalance(r) == 2 && getBalance(r.Left) == 1)
            r = llrotation(r);
        else if (getBalance(r) == -2 && getBalance(r.Right) == -1)
            r = rrrotation(r);
        else if (getBalance(r) == -2 && getBalance(r.Right) == 1)
            r = rlrotation(r);
        else if (getBalance(r) == 2 && getBalance(r.Left) == -1)
            r = lrrotation(r);

        return r;
    }
 
    ZMLNode deleteNode(ZMLNode p, int Weight)
    {
        if (!p.Left && !p.Right)
        {
            if (p == self.Root)
                self.Root = null;
            return null;
        }

        ZMLNode t;
        ZMLNode q;
        if (p.Weight < Weight)
            p.Right = deleteNode(p.Right, Weight);
        else if (p.Weight > Weight)
            p.Left = deleteNode(p.Left, Weight);
        else
        {
            if (p.Left)
            {
                q = inpre(p.Left);
                p.Name = q.Name;
                p.Data = q.Data;
                p.Root = q.Root;
                p.Weight = q.Weight;
                p.Left = deleteNode(p.Left, q.Weight);
            }
            else
            {
                q = insuc(p.Right);
                p.Name = q.Name;
                p.Data = q.Data;
                p.Root = q.Root;
                p.Weight = q.Weight;
                p.Right = deleteNode(p.Right, q.Weight);
            }
        }

        if (getBalance(p) == 2 && getBalance(p.Left) == 1)
            p = llrotation(p);
        else if (getBalance(p) == 2 && getBalance(p.Left) == -1)
            p = lrrotation(p);
        else if (getBalance(p) == 2 && getBalance(p.Left) == 0)
            p = llrotation(p);
        else if (getBalance(p) == -2 && getBalance(p.Right) == -1)
            p = rrrotation(p);
        else if (getBalance(p) == -2 && getBalance(p.Right) == 1)
            p = rlrotation(p);
        else if (getBalance(p) == -2 && getBalance(p.Right) == 0)
            p = llrotation(p);

        return p;
    }
    
    ZMLNode inpre(ZMLNode p)
    {
        while (p.Right)
            p = p.Right;

        return p;    
    }

    ZMLNode insuc(ZMLNode p)
    {
        while(p.Left)
            p = p.Left;

        return p;    
    }
}

