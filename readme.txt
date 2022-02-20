
	Z-Xtensible Markup Language
	Created: 05/02/22
	Date Format for Project : DD/MM/YY

	The name is a bit of a misnomer,  ZML is actually a parser 
	for an XML syntax-like language, created by Sarah Blackburn
	for storage of information outside of standard (G)ZDoom
	project data.

		Just a tidbit, of info, this is my second XML interpreter,
		I did one for Unity in C#.


Basic Mod Concept:
------------------
	It works like most of my mods.  ZML is the base mod, which includes
	just the parser code.  Users then need to decide how to use the mod,
	do they include it with their work, or do they instruct users of
	their mod to download ZML as well?  That decision depends on how the
	other mod works.

	In the case of my project, Viridian Asylum, to allow the game to be
	modded, ZML is included, as a mod (based around how VA is built),
	such that mods to Viridian Asylum can just include ZML data,
	rather than needing code as well.


Parser Concept:
---------------

	Headers : Every mod containing ZML data must contain a header that points to it.
			- Headers are simple files that follow ZML syntax:

				<zml>
					<include>path/file.zml</include>
				</zml>

			- This file should be defined like the ZScript translation unit,
			  thus in the root of the archive.

			- This file must be unique to the archive.

			- This file must be named "zml.txt"

	Defined Tags : Tags are reserved words that the parser will scan for.

			- Tags are defined in a definition file.  This file follows the
			  standards established for such files.

			- This file must be unique to the archive.

			- This file must be located in the root of the directory.

			- This file must be named "zmldefs.txt"

			- ZMLDEFS is more complex as users are defining how their data is stored.

	ZML Files : These are the actual ZML data files

			- These are loaded last.  Tags and headers must be read.

			- These are explicitly error checked to attempt to avoid VM aborting.

			- Where these files are located in the archive are controlled by the
			  header files.  It is recommended that users create a "zml" folder
			  within archives to create namespace that the engine ignores.

			- ZML files may have any name and any extension.  The ".txt" or ".zml"
			  extensions are recommended.


What defines type?
------------------
	Type is expressly defined, either by the parser itself or the user.  No exceptions, ZScript 
	has to know what to cast to.  Both tags and attributes must be typed when defined.


What ZML Does NOT Do:
---------------------
	Anything relating to HTML.  Yes namespacing was originally created to avoid tag issues with
	HTML; seriously who is gonna make a <table/> tag that goes alongside HTML that is also going
	to read that same file?  Ok, rant about why not just enforcing strict naming and just breaking
	things when users don't follow the rules, I mean this is half of why I write code, it breaks
	if you don't do it right, so follow the rules or don't complain to me, ok, rant over.

				
Established Syntax For ZML Files:
---------------------------------
	ZML follows standard XML syntax:

	<root>
		<child>
			<subchild>
				<subchild>data</subchild>
			</subchild>
		</child>
	</root>

	This syntax is the same for header and actual ZML data files.

	Tags:
		<zml>data</zml> - openning and closing tags are the standard way of encapsulating data.
		<zml/> - a tag may be self-terminated if the tag is not going to contain children.

	Attributes:
		Attributes are basically variables, thus they are words, or names given to data.
		They follow standard XML syntax:
	
			<tag attributeName=dataOfType></tag>

	Namespacing:
		Namespaces allows naming conflicts to be resolved through prefixing.  ZML deviates slightly
		from XML in this regard by alowing for two additional QOL features.  First, prefixes may
		themselves be full strings, defined in ZMLDEFS, and also aliased.  Second, namespaces may
		be established for entire projects through the "namespace" attribute of the <zml/> tag.

		Inline prefixes within data:
			<namespace:zml>data</zml>

		Establishing a prefix in the root:
			<zml namespace="stringName">data</zml>

			Note that if this is done in the header file, all files will be included
			under that namespace.

		Can you create inline prefixes within global prefixes?  Absolutely.  This creates local prefixes!
			<zml namespace="globalPrefix">
				<.localPrefix:tag>data</tag>
			</zml>

				- NOTE!  The period ( . ) before the local prefix is required!
			
				Users use the full prefix when searching for elements:
					FindElements("globalPrefix.localPrefix);
				This returns a collection of of elements from the global namespace,
				with the specified local namespace.

		What namespacing allows for?
			Besides name conflict resolution, namespacing allows project data to be isolated,
			thus manipulated within the ZML tree more efficently as there is now a global
			name with which to search for relevant data.


Esablished Syntax for the ZMLDEFS Lump:
---------------------------------------

	- This lump is not case sensitive.  Everything is assumed to be lowercase, and is handled as such.
	- The brackets and semicolons are required.
	- The presence of a flag in a tag definition is treated as a true value.
	- Standard C-style comments are allowed.

	Keywords - define block sections of the definition:
		tag - a ZML tag.  This may be opened with brackets and further information added.
		attribute - this defines the start of an attribute list that must be opened with brackets.

	Flags - allow the parser to handle certain situations according to the meaning of the flag.
		    Flags function as a means of error correction and customization.  The flags of the object
			in the tree take precedence over any descendents unless otherwise specified.

		addtype - this means if another tag is parsed with the same name, its data is added to this one, with possible overwrite, 
				  to resolve the conflict.
		overwrite - this means the conflict will be resolved by completely overwriting this tag with the incoming tag's data.
		obeyincoming - this means the tag's flags are superseded by any incoming tag.  This tag's flags are obeyed if a
					   conflicting tag does not specifiy means of conflict resolution.

		Note that "addtype" and "overwrite" are mutually exclusive.  You can only do one or the other.
		No conflict resolution flag implies strict resolution, which means the incoming tag is discarded as a likely copy,
		or the base definition should not be modified.

	Type Words - these result in an enumeration internally that determine what type the data is handled as.
		These are written in double quotes, as strings:
			- t_int
			- t_float
			- t_double
			- t_string
			- t_bool
			- t_none : this type is special as it signifies that a tag, and only a tag, is a root tag that will contain other elements.

	Tag Word - this is the word or name given to the tag, written as a string.
		For example:
			<musicList></musicList>

	Example of a tag definition with flags and attributes:

		tag "tagWord", "typeWord"
		{
			flag;

			attributes
			{
				"attributeName", "typeWord";
			}
		}

	Example of a tag defining only its name and type:

		tag "tagword, "typeWord";
		

Reserved Tags & Attributes:
---------------------------
	Tags:
		<zml></zml> - this is the root tag that defines the file as ZML code
		<include/> - this child tag is used only in ZML header files to direct the parser to 
		     	     actual ZML data to interpret.
	
	Attributes:
		namespace - type of string, this attribute is used within the <zml/> tag to identify
			    that all further data within the file, or included files, is to be prefixed.

