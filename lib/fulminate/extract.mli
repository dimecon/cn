type statement = Locations.t * Cnstatement.statement Cnprog.t list

type statements = statement list

type loop = bool * Locations.t * Locations.t * statements ArgumentTypes.t
(* first location is for the loop condition; second is for the entire loop *)

type loops = loop list

type fn_body = statements * loops

type fn_args_and_body = (ReturnTypes.t * fn_body) ArgumentTypes.t

type fn_largs_and_body = (ReturnTypes.t * fn_body) LogicalArgumentTypes.t

val sym_subst
  :  Sym.t * BaseTypes.t * Sym.t ->
  [ `Rename of Sym.t | `Term of IndexTerms.t ] Subst.t

val loop_subst : [ `Rename of Sym.t | `Term of IndexTerms.t ] Subst.t -> loop -> loop

val fn_args_and_body_subst
  :  [ `Rename of Sym.t | `Term of IndexTerms.t ] Subst.t ->
  fn_args_and_body ->
  fn_args_and_body

val fn_largs_and_body_subst
  :  [ `Rename of Sym.t | `Term of IndexTerms.t ] Subst.t ->
  fn_largs_and_body ->
  fn_largs_and_body

type instrumentation =
  { fn : Sym.t;
    fn_loc : Locations.t;
    internal : fn_args_and_body option;
    trusted : bool;
    is_static : bool
  }

val collect_instrumentation
  :  Cerb_frontend.Cabs.translation_unit ->
  'a Mucore.file ->
  instrumentation list * BaseTypes.Surface.t Hashtbl.Make(Sym).t

val args_and_body_list_of_mucore : 'a Mucore.file -> 'a Mucore.args_and_body list

val ghost_args_and_their_call_locs
  :  'a Mucore.file ->
  (Cerb_location.t * IndexTerms.t Cnprog.t list) list

val max_num_of_ghost_args : 'a Mucore.file -> int
