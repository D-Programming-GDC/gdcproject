[//]: # (Permission is granted to make and distribute verbatim copies)
[//]: # (of this entire document without royalty provided the)
[//]: # (copyright notice and this permission notice are preserved.)

### GDC Documentation ###

At the moment, documentation for GDC, especially the internals, is
sparse.  The DMD frontend and the GCC internals aren't very well
documented either.  This page will hopefully help provide insight on
GDC's internals.

#### GCC Internals ####

GCC is a compiler for many languages and many targets, so it is
divided into pieces.

<dl>
<dt>*Front-End*:</dt>
<dd>Turns the source code into a language-independent representation
[GENERIC][generic].</dd>

<dt>*Middle-End*:</dt>
<dd>Breaks down the GENERIC expressions into a lower level IL used for
target and language independent optimisations [GIMPLE][gimple].</dd>

<dt>*Back-End*:</dt>
<dd>Lowers the GIMPLE into a lower level IR and emits target-specific
assembler instructions [RTL][rtl].</dd>
</dl>

What we know as "GDC" is only an implementation of the Front-end part
of GCC.  GDC is located within its own subfolder in the core GCC source
tree (*gcc/d*).  It is within this subfolder that we must perform all
changes to the language.

GCC has other Front-ends such as C (*gcc/c*), C++ (*gcc/cp*), Java
(*gcc/java*), and Go (*gcc/go*), etc.  You could look at these for
advice, but one probably shouldn't.

#### GDC Internals ####

The D Front-end contains the lexer and parser.  These together turn the
source file into GENERIC.  The GDC frontend relies heavily on the
Digital Mars D (DMD) sources to perform this work, and you will find
the entire DMD Front-end sources in a subfolder (*gcc/d/dfrontend*).

Other parts of the D Front-end outside this folder are part of GDC.
Certain files are special as parts of the GCC back-end depend on
their names.

<dl>
<dt>*config-lang.in*:</dt>
<dd>This file is a shell script that defines some variables describing GDC, including:

  <dl>
  <dt>language:</dt>
  <dd>Gives the name of the language for some purposes such as
  *--enable-languages*</dd>

  <dt>compilers:</dt>
  <dd>Name of each compiler proper that will be run by the driver.</dd>

  <dt>target-libs:</dt>
  <dd>Lists runtime libraries that should not be configured if GDC is not
  built. Current list is Phobos, Zlib, and Backtrace.</dd>

  <dt>build-by-default:</dt>
  <dd>Defined as 'no' so GDC is not built unless enabled in an
  *--enable-languages* argument.</dd>
  </dl>
</dd>

<dt>*Make-lang.in*:</dt>
<dd>Provides all Front-end language build hooks GCC expects to be
implemented, and adds the D2 testsuite to be ran under '*make check*'.</dd>

<dt>*lang.opt*:</dt>
<dd>Enregisters the set of command-line argument and their help text that
GDC accepts.  Eg: *-frelease*, *-fno-bounds-check*.</dd>

<dt>*lang-specs.h*:</dt>
<dd>This file provides entries for default_compilers in gcc.c, it's main
purpose is to tell other compilers how to handle a D source file.
This overrides the default of giving an error that a D compiler is not
installed.</dd>

<dt>*d-tree.def*:</dt>
<dd>This file, which need not exist, defines any GDC specific tree codes.
Eg: *UNSIGNED_RSHIFT_EXPR*, *FLOAT_MOD_EXPR*.</dd>
</dl>

#### GDC Front-End Interface ###

The following sources implement various methods among the Front-end AST
nodes.

<dl>
<dt>*gcc/d/d-toir.cc* (toIR):</dt>
<dd>Defined for all Statement sub-classes.

Generates a statement expression, which have side effects but usually no
interesting value.</dd>

<dt>*gcc/d/d-elem.cc* (toElem):</dt>
<dd>Defined for all Expression sub-classes.

Generates an expression, be it an unary arithmetic, binary arithmetic,
function call, etc.</dd>

<dt>*gcc/d/d-todt.cc* (toDt):</dt>
<dd>Defined for most Initializer, Type and Expression sub-classes.

Generates a constant to be used as an initial value for declarations.</dd>

<dt>*gcc/d/d-objfile.cc* (toObjFile):</dt>
<dd>Defined for all Declaration sub-classes.

Generates a static variable or function declaration to be sent to the
Back-end.</dd>

<dt>*gcc/d/d-decls.cc* (toSymbol):</dt>
<dd>Defined for all Dsymbol sub-classes.

Generates a given symbol, which could be any kind of global, local, or
field declaration.</dd>

<dt>*gcc/d/d-ctype.cc* (toCtype):</dt>
<dd>Defined for all Type sub-classes.

Generates the type object code as is represented in the GCC Back-end.</dd>
</dl>

Currently work is under way in upstream DMD to convert all these
methods into Visitor classes as part of the 2.065, 2.066 releases to
allow work to begin on porting the D Front-end to D.  So expect the
convention and names of these files to change in the near future.

#### GDC Back-End Interface ####

The Middle-end uses callbacks to interface with the Front-end via
"lang_hooks" (See *gcc/d/d-lang.cc*).

The following are implemented by GDC:

<dl>
<dt>*lang_hooks.name*:</dt>
<dd>String identifying the Front-end.  ("GNU D")</dd>

<dt>*lang_hooks.init_options*:</dt>
<dt>*lang_hooks.init_options_struct*:</dt>
<dt>*lang_hooks.initialize_diagnostics*:</dt>
<dd>Initialize both Front-end and back-end configurable settings before
the compiler starts handling command-line arguments.</dd>

<dt>*lang_hooks.option_lang_mask*:</dt>
<dd>The language mask used for option parsing.  ("CL_D")

<dt>*lang_hooks.handle_option*:</dt>
<dd>Handles a parsed Front-end command-line arguments defined in
*lang.opt*.</dd>

<dt>*lang_hooks.post_options*:</dt>
<dd>Called after all command-line arguments have been parsed to allow
further processing.</dd>

<dt>*lang_hooks.init*:</dt>
<dt>*lang_hooks.init_ts*:</dt>
<dd>Called after processing options to initialize the Front-end to be
ready to begin parsing.</dd>

<dt>*lang_hooks.parse_file*:</dt>
<dd>Parse all files passed to GDC, this runs all semantic analysis passes
and generates backend codegen.</dd>

<dt>*lang_hooks.attribute_table*:</dt>
<dt>*lang_hooks.common_attribute_table*:</dt>
<dt>*lang_hooks.format_attribute_table*:</dt>
<dd>All machine-independant attributes handled by GDC.  The common and
format attribute table is internally used by the gcc.builtins module,
whilst the main attribute table holds all @attributes recognised by
gcc.attribute.</dd>

<dt>*lang_hooks.get_alias_set*:</dt>
<dd>Returns the alias set for a type or expression.  For D codegen, we
currently assume that everything aliases everything else, until some
solid rules are defined.</dd>

<dt>*lang_hooks.types_compatible_p*:</dt>
<dd>Compares two (possibly D specific) types for equivalence.</dd>

<dt>*lang_hooks.builtin_function*:</dt>
<dt>*lang_hooks.builtin_function_ext_scope*:</dt>
<dt>*lang_hooks.register_builtin_type*:</dt>
<dd>Do language specific processing on builtins.  For GDC, this is used to
build the list of declarations to push into the gcc.builtins module.</dd>

<dt>*lang_hooks.finish_incomplete_type*:</dt>
<dd>Finish up incomplete types at the end of compilation.  Used to
specially handle zero-length declarations.</dd>

<dt>*lang_hooks.gimplify_expr*:</dt>
<dd>Perform language specific lowering of D codegen.</dd>

<dt>*lang_hooks.classify_record*:</dt>
<dd>For purposes of debug information, return information on whether an
aggregate type is a class, interface or struct.</dd>

<dt>*lang_hooks.eh_personality*:</dt>
<dt>*lang_hooks.eh_runtime_type*:</dt>
<dd>The GDC specific personality function used to interface with
libunwind, and the Object type thrown.</dd>

<dt>*lang_hooks.pushdecl*:</dt>
<dt>*lang_hooks.getdecls*:</dt>
<dt>*lang_hooks.global_bindings_p*:</dt>
<dd>Hooks for pushing, retrieving and tracking all variables in the
current binding level or lexical scope being compiled.</dd>

<dt>*lang_hooks.final_write_globals*:</dt>
<dd>Do all final processing on globals and compile them down to
assembly.</dd>

<dt>*lang_hooks.types.type_for_mode*:</dt>
<dt>*lang_hooks.types.type_for_size*:</dt>
<dd>For a given mode or precision, return the suitable D type.</dd>

<dt>*lang_hooks.type.type_promotes_to*:</dt>
<dd>For a given type, apply default promotions.  This is required
for supporting variadic arguments.</dd>

</dl>

[generic]: http://gcc.gnu.org/onlinedocs/gccint/GENERIC.html
[gimple]: http://gcc.gnu.org/onlinedocs/gccint/GIMPLE.html
[rtl]: http://gcc.gnu.org/onlinedocs/gccint/RTL.html
