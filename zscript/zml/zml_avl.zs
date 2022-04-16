/*

    What: Z-xtensible Markup Language AVL Tree Definition
    Who: Sarah Blackburn
    When: 05/02/22

    Credit to the author on this site: https://www.guru99.com/avl-tree.html#12
    The code was copied and modified for ZScript.  Thank you!  I never quite
    wrapped my head around these things!

*/


/*class ZMLNode
{
    ZMLNode left, right;
    int data, height;

    ZMLNode Init(int data = 0)
    {
        self.left = self.right = null;
        self.data = data;
        self.height = 0;
        return self;
    }
}*/

class ZMLNode
{
    ZMLNode root,       // Children tree
        left, right;    // Sibling trees
    int height,
        weight;

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

    string HashString() { return string.Format("%szml%s", Name, Data); }

    ZMLNode Init(string Name, string Data) 
    { 
        self.root = self.left = self.right = null; 
        self.height = 0;
        self.Name = Name;
        self.Data = Data;
        self.weight = Hash(HashString());
        return self;
    }

    int calc_height(ZMLNode p)
    {
        if (p.left && p.right)
        {
            if (p.left.height < p.right.height)
                return p.right.height + 1;
            else
                return p.left.height + 1;
        }
        else if (p.left && !p.right)
            return p.left.height + 1;
        else if (!p.left && p.right)
            return p.right.height + 1;

        return 0;
    }

    int getBalance(ZMLNode n)
    {
        if (n.left && n.right)
            return n.left.height - n.right.height; 
        else if (n.left && !n.right)
            return n.left.height; 
        else if (!n.left && n.right )
            return -n.right.height;

        return 0;
    }

    ZMLNode llrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        p = n;
        tp = p.left;

        p.left = tp.right;
        tp.right = p;

        return tp; 
    }


    ZMLNode rrrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        p = n;
        tp = p.right;

        p.right = tp.left;
        tp.left = p;

        return tp; 
    }


    ZMLNode rlrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        ZMLNode tp2;
        p = n;
        tp = p.right;
        tp2 = p.right.left;

        p.right = tp2.left;
        tp.left = tp2.right;
        tp2.left = p;
        tp2.right = tp; 
        
        return tp2; 
    }

    ZMLNode lrrotation(ZMLNode n)
    {
        ZMLNode p;
        ZMLNode tp;
        ZMLNode tp2;
        p = n;
        tp = p.left;
        tp2 = p.left.right;

        p.left = tp2.right;
        tp.right = tp2.left;
        tp2.right = p;
        tp2.left = tp; 
        
        return tp2; 
    }

    ZMLNode insert(ZMLNode r, string Name, string Data)
    {      
        if (!r)
        {
            ZMLNode n;
            n = new("ZMLNode").Init(Name, Data);
            r = n;
            r.height = 1; 
            return r;             
        }
        else
        {
            if (weight < r.weight)
                r.left = insert(r.left, Name, Data);
            else
                r.right = insert(r.right, Name, Data);
        }

        r.height = calc_height(r);

        if (getBalance(r) == 2 && getBalance(r.left) == 1)
            r = llrotation(r);
        else if (getBalance(r) == -2 && getBalance(r.right) == -1)
            r = rrrotation(r);
        else if (getBalance(r) == -2 && getBalance(r.right) == 1)
            r = rlrotation(r);
        else if (getBalance(r) == 2 && getBalance(r.left) == -1)
            r = lrrotation(r);

        return r;
    }
 
    ZMLNode deleteNode(ZMLNode p, int weight)
    {
        if (!p.left && !p.right)
        {
            if (p == self.root)
                self.root = null;
            return null;
        }

        ZMLNode t;
        ZMLNode q;
        if (p.weight < weight)
            p.right = deleteNode(p.right, weight);
        else if (p.weight > weight)
            p.left = deleteNode(p.left, weight);
        else
        {
            if (p.left)
            {
                q = inpre(p.left);
                p.Name = q.Name;
                p.Data = q.Data;
                p.root = q.root;
                p.weight = q.weight;
                p.left = deleteNode(p.left, q.weight);
            }
            else
            {
                q = insuc(p.right);
                p.Name = q.Name;
                p.Data = q.Data;
                p.root = q.root;
                p.weight = q.weight;
                p.right = deleteNode(p.right, q.weight);
            }
        }

        if (getBalance(p) == 2 && getBalance(p.left) == 1)
            p = llrotation(p);
        else if (getBalance(p) == 2 && getBalance(p.left) == -1)
            p = lrrotation(p);
        else if (getBalance(p) == 2 && getBalance(p.left) == 0)
            p = llrotation(p);
        else if (getBalance(p) == -2 && getBalance(p.right) == -1)
            p = rrrotation(p);
        else if (getBalance(p) == -2 && getBalance(p.right) == 1)
            p = rlrotation(p);
        else if (getBalance(p) == -2 && getBalance(p.right) == 0)
            p = llrotation(p);

        return p;
    }
    
    ZMLNode inpre(ZMLNode p)
    {
        while (p.right)
            p = p.right;

        return p;    
    }

    ZMLNode insuc(ZMLNode p)
    {
        while(p.left)
            p = p.left;

        return p;    
    }
}

