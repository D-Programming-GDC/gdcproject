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

 * **Front-End**

    Turns the source code into a language-independent representation
    [GENERIC][generic].

 * **Middle-End**

    Breaks down the GENERIC expressions into a lower level IL used for target
    and language independent optimisations [GIMPLE][gimple].

 * **Back-End**

    Lowers the GIMPLE into a lower level IR and emits target-specific assembler
    instructions [RTL][rtl].

- - -

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

 * **config-lang.in**

    This file is a shell script that defines some variables describing GDC,
    including:

    - *language*:

        Gives the name of the language for some purposes such as
        **--enable-languages**

    - *compilers*:

        Name of each compiler proper that will be run by the driver.

    - *target_libs*:

        Lists runtime libraries that should not be configured if GDC is not
        built.  Current list is Phobos, Zlib, and Backtrace.

    - *build_by_default*:

        Defined as 'no' so GDC is not built unless enabled in an
        **--enable-languages** argument.

 * **Make-lang.in**

    Provides all Front-end language build hooks GCC expects to be implemented,
    and adds the D2 testsuite to be ran under '**make check**'.

 * **lang.opt**:

    Enregisters the set of command-line argument and their help text that
    GDC accepts.  Eg: **-frelease**, **-fno-bounds-check**.

 * **lang-specs.h**:

    This file provides entries for default_compilers in gcc.c, it's main
    purpose is to tell other compilers how to handle a D source file.  This
    overrides the default of giving an error that a D compiler is not installed.

 * **d-tree.def**:

    This file, which need not exist, defines any GDC specific tree codes.

    - *UNSIGNED_RSHIFT_EXPR*:

        Unsigned right shift operator.

    - *FLOAT_MOD_EXPR*:

        Floating-point modulo division operator.

- - -

#### GDC Front-End Interface ###

The following sources implement various methods among the Front-end AST nodes.

 * **gcc/d/d-toir.cc** (toIR):

    Defined for all Statement sub-classes.  Generates a statement expression,
    which have side effects but usually no interesting value.

 * **gcc/d/d-elem.cc** (toElem):

    Defined for all Expression sub-classes.  Generates an expression, be it an
    unary arithmetic, binary arithmetic, function call, etc.

 * **gcc/d/d-todt.cc** (toDt):

    Defined for most Initializer, Type and Expression sub-classes.  Generates a
    constant to be used as an initial value for declarations.

 * **gcc/d/d-objfile.cc** (toObjFile):

    Defined for all Declaration sub-classes.  Generates a static variable or
    function declaration to be sent to the Back-end.

 * **gcc/d/d-decls.cc** (toSymbol):

    Defined for all Dsymbol sub-classes.  Generates a given symbol, which could
    be any kind of global, local, or field declaration.

 * **gcc/d/d-ctype.cc** (toCtype):

    Defined for all Type sub-classes.  Generates the type object code as is
    represented in the GCC Back-end.

- - -

Currently work is under way in upstream DMD to convert all these methods into
Visitor classes as part of the 2.065, 2.066 releases to allow work to begin on
porting the D Front-end to D.  So expect the convention and names of these files
to change in the near future.

#### GDC Back-End Interface ####

The Middle-end uses callbacks to interface with the Front-end via
"lang_hooks" (See *gcc/d/d-lang.cc*).

The following are implemented by GDC:

 * **lang_hooks.name**:

    String identifying the Front-end.  ("GNU D")

 * **lang_hooks.init_options**:<br/>
   **lang_hooks.init_options_struct**:<br/>
   **lang_hooks.initialize_diagnostics**:

    Initialize both Front-end and back-end configurable settings before the
    compiler starts handling command-line arguments.

 * **lang_hooks.option_lang_mask**:

    The language mask used for option parsing.  ("CL_D")

 * **lang_hooks.handle_option**:

    Handles a parsed Front-end command-line arguments defined in **lang.opt**.

 * **lang_hooks.post_options**:

    Called after all command-line arguments have been parsed to allow further
    processing.

 * **lang_hooks.init**:<br/>
    **lang_hooks.init_ts**:

    Called after processing options to initialize the Front-end to be ready to
    begin parsing.

 * **lang_hooks.parse_file**:

    Parse all files passed to GDC, this runs all semantic analysis passes and
    generates backend codegen.

 * **lang_hooks.attribute_table**:<br/>
   **lang_hooks.common_attribute_table**<br/>
   **lang_hooks.format_attribute_table**

    All machine-independant attributes handled by GDC.  The common and format
    attribute table is internally used by the gcc.builtins module, whilst the
    main attribute table holds all @attributes recognised by gcc.attribute.

 * **lang_hooks.get_alias_set**:

    Returns the alias set for a type or expression.  For D codegen, we currently
    assume that everything aliases everything else, until some solid rules are
    defined.

 * **lang_hooks.types_compatible_p**:

    Compares two (possibly D specific) types for equivalence.

 * **lang_hooks.builtin_function**:<br/>
   **lang_hooks.builtin_function_ext_scope**:<br/>
   **lang_hooks.register_builtin_type**:

    Do language specific processing on builtins.  For GDC, this is used to
    build the list of declarations to push into the gcc.builtins module.

 * **lang_hooks.finish_incomplete_type**:

    Finish up incomplete types at the end of compilation.  Used to specially
    handle zero-length declarations.

 * **lang_hooks.gimplify_expr**:

    Perform language specific lowering of D codegen.

 * **lang_hooks.classify_record**:

    For purposes of debug information, return information on whether an
    aggregate type is a class, interface or struct.

 * **lang_hooks.eh_personality**:<br/>
   **lang_hooks.eh_runtime_type**:

    The GDC specific personality function used to interface with libunwind, and
    the Object type thrown.

 * **lang_hooks.pushdecl**:<br/>
   **lang_hooks.getdecls**:<br/>
   **lang_hooks.global_bindings_p**:

    Hooks for pushing, retrieving and tracking all variables in the current
    binding level or lexical scope being compiled.

 * **lang_hooks.final_write_globals**:

    Do all final processing on globals and compile them down to assembly.

 * **lang_hooks.types.type_for_mode**:<br/>
   **lang_hooks.types.type_for_size**:

    For a given mode or precision, return the suitable D type.

 * **lang_hooks.type.type_promotes_to**:

    For a given type, apply default promotions.  This is required for supporting
    variadic arguments.

[generic]: http://gcc.gnu.org/onlinedocs/gccint/GENERIC.html
[gimple]: http://gcc.gnu.org/onlinedocs/gccint/GIMPLE.html
[rtl]: http://gcc.gnu.org/onlinedocs/gccint/RTL.html
