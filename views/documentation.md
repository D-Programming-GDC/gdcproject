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

<table class="table-condensed">
  <tr>
    <td nowrap><b>Front-End</b>:</td>
    <td>Turns the source code into a language-independent representation
    <a href="http://gcc.gnu.org/onlinedocs/gccint/GENERIC.html">GENERIC</a>.</td>
  </tr>
  <tr>
    <td nowrap><b>Middle-End</b>:</td>
    <td>Breaks down the GENERIC expressions into a lower level IL used for
    target and language independent optimisations
    <a href="http://gcc.gnu.org/onlinedocs/gccint/GIMPLE.html">GIMPLE</a>.</td>
  </tr>
  <tr>
    <td nowrap><b>Back-End</b>:</td>
    <td>Lowers the GIMPLE into a lower level IR and emits target-specific
    assembler instructions
    <a href="http://gcc.gnu.org/onlinedocs/gccint/RTL.html">RTL</a>.</td>
  </tr>
</table>
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

<table class="table">
  <tr>
    <td nowrap><b>config-lang.in</b>:</td>
    <td>This file is a shell script that defines some variables describing GDC, including:
      <table class="table-condensed">
        <tr>
          <td><i>language</i>:</td>
          <td>Gives the name of the language for some purposes such as
          <b>--enable-languages</b></td>
        </tr>
        <tr>
          <td><i>compilers</i>:</td>
          <td>Name of each compiler proper that will be run by the driver.</td>
        </tr>
        <tr>
          <td><i>target_libs</i>:</td>
          <td>Lists runtime libraries that should not be configured if GDC is
          not built. Current list is Phobos, Zlib, and Backtrace</td>
        </tr>
        <tr>
          <td><i>build_by_default</i>:</td>
          <td>Defined as 'no' so GDC is not built unless enabled in an
          <b>--enable-languages</b> argument.</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td nowrap><b>Make-lang.in</b>:</td>
    <td>Provides all Front-end language build hooks GCC expects to be
    implemented, and adds the D2 testsuite to be ran under '<b>make check</b>'.</td>
  </tr>
  <tr>
    <td><b>lang.opt</b>:</td>
    <td>Enregisters the set of command-line argument and their help text that
    GDC accepts.  Eg: <b>-frelease</b>, <b>-fno-bounds-check</b>.</td>
  </tr>
  <tr>
    <td><b>lang-specs.h</b>:</td>
    <td>This file provides entries for default_compilers in gcc.c, it's main
    purpose is to tell other compilers how to handle a D source file.  This
    overrides the default of giving an error that a D compiler is not installed.</td>
  </tr>
  <tr>
    <td nowrap><b>d-tree.def</b>:</td>
    <td>This file, which need not exist, defines any GDC specific tree codes.
      <table class="table-condensed">
        <tr>
          <td><i>UNSIGNED_RSHIFT_EXPR</i>:</td>
          <td>Unsigned right shift operator.</td>
        </tr>
        <tr>
          <td><i>FLOAT_MOD_EXPR</i>:</td>
          <td>Floating-point modulo division operator.</td>
        </tr>
      </table>
    </td>
  </tr>
</table>
- - -

#### GDC Front-End Interface ###

The following sources implement various methods among the Front-end AST
nodes.

<table class="table">
  <tr>
    <td nowrap><b>gcc/d/d-toir.cc</b> (toIR):</td>
    <td>Defined for all Statement sub-classes.</td>
    <td>Generates a statement expression, which have side effects but usually no
    interesting value.</td>
  </tr>
  <tr>
    <td nowrap><b>gcc/d/d-elem.cc</b> (toElem):</td>
    <td>Defined for all Expression sub-classes.</td>
    <td>Generates an expression, be it an unary arithmetic, binary arithmetic,
    function call, etc.</td>
  </tr>
  <tr>
    <td nowrap><b>gcc/d/d-todt.cc</b> (toDt):</td>
    <td>Defined for most Initializer, Type and Expression sub-classes.</td>
    <td>Generates a constant to be used as an initial value for declarations.</td>
  </tr>
  <tr>
    <td nowrap><b>gcc/d/d-objfile.cc</b> (toObjFile):</td>
    <td>Defined for all Declaration sub-classes.</td>
    <td>Generates a static variable or function declaration to be sent to the
    Back-end.</td>
  </tr>
  <tr>
    <td nowrap><b>gcc/d/d-decls.cc</b> (toSymbol):</td>
    <td>Defined for all Dsymbol sub-classes.</td>
    <td>Generates a given symbol, which could be any kind of global, local, or
    field declaration.</td>
  </tr>
  <tr>
    <td nowrap><b>gcc/d/d-ctype.cc</b> (toCtype):</td>
    <td>Defined for all Type sub-classes.</td>
    <td>Generates the type object code as is represented in the GCC Back-end.</td>
  </tr>
</table>
- - -
Currently work is under way in upstream DMD to convert all these
methods into Visitor classes as part of the 2.065, 2.066 releases to
allow work to begin on porting the D Front-end to D.  So expect the
convention and names of these files to change in the near future.

#### GDC Back-End Interface ####

The Middle-end uses callbacks to interface with the Front-end via
"lang_hooks" (See *gcc/d/d-lang.cc*).

The following are implemented by GDC:

<table class="table">
  <tr>
    <td nowrap><b>lang_hooks.name</b>:</td>
    <td>String identifying the Front-end.  ("GNU D")</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.init_options</b>:<br/>
    <b>lang_hooks.init_options_struct</b>:<br/>
    <b>lang_hooks.initialize_diagnostics</b>:</td>
    <td>Initialize both Front-end and back-end configurable
    settings before the compiler starts handling command-line arguments.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.option_lang_mask</b>:</td>
    <td>The language mask used for option parsing.  ("CL_D")</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.handle_option</b>:</td>
    <td>Handles a parsed Front-end command-line arguments defined in
    <b>lang.opt</b>.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.post_options</b>:</td>
    <td>Called after all command-line arguments have been parsed to allow
    further processing.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.init</b>:<br/>
    <b>lang_hooks.init_ts</b>:</td>
    <td>Called after processing options to initialize the Front-end to be
    ready to begin parsing.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.parse_file</b>:</td>
    <td>Parse all files passed to GDC, this runs all semantic analysis passes
    and generates backend codegen.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.attribute_table</b>:<br/>
    <b>lang_hooks.common_attribute_table</b><br/>
    <b>lang_hooks.format_attribute_table</b></td>
    <td>All machine-independant attributes handled by GDC.  The common and
    format attribute table is internally used by the gcc.builtins module,
    whilst the main attribute table holds all @attributes recognised by
    gcc.attribute.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.get_alias_set</b>:</td>
    <td>Returns the alias set for a type or expression.  For D codegen, we
    currently assume that everything aliases everything else, until some
    solid rules are defined.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.types_compatible_p</b>:</td>
    <td>Compares two (possibly D specific) types for equivalence.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.builtin_function</b>:<br/>
    <b>lang_hooks.builtin_function_ext_scope</b>:<br/>
    <b>lang_hooks.register_builtin_type</b>:</td>
    <td>Do language specific processing on builtins.  For GDC, this is used to
    build the list of declarations to push into the gcc.builtins module.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.finish_incomplete_type</b>:</td>
    <td>Finish up incomplete types at the end of compilation.  Used to
    specially handle zero-length declarations.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.gimplify_expr</b>:</td>
    <td>Perform language specific lowering of D codegen.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.classify_record</b>:</td>
    <td>For purposes of debug information, return information on whether an
    aggregate type is a class, interface or struct.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.eh_personality</b>:<br/>
    <b>lang_hooks.eh_runtime_type</b>:</td>
    <td>The GDC specific personality function used to interface with
    libunwind, and the Object type thrown.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.pushdecl</b>:<br/>
    <b>lang_hooks.getdecls</b>:<br/>
    <b>lang_hooks.global_bindings_p</b>:</td>
    <td>Hooks for pushing, retrieving and tracking all variables in the
    current binding level or lexical scope being compiled.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.final_write_globals</b>:</td>
    <td>Do all final processing on globals and compile them down to assembly.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.types.type_for_mode</b>:<br/>
    <b>lang_hooks.types.type_for_size</b>:</td>
    <td>For a given mode or precision, return the suitable D type.</td>
  </tr>
  <tr>
    <td nowrap><b>lang_hooks.type.type_promotes_to</b>:</td>
    <td>For a given type, apply default promotions.  This is required for
    supporting variadic arguments.</td>
  </tr>
</table>

