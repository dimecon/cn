open Lem_pervasives
open Ctype
open Lem_assert_extra

open Core
open Annot

open Mucore
module Mu = Core_to_mucore.Mu
open Mu




let rec ib_texpr label e = 

  let (M_Expr(loc, oannots, e_)) = e in
  let wrap e_= M_Expr(loc, oannots, e_) in
  let taux = ib_texpr label in
  match e_ with
  (* | M_Ecase( asym2, pats_es) -> *)
  (*    let pats_es =  *)
  (*      (Lem_list.map (fun (pat,e) ->  *)
  (*           (pat, taux e) *)
  (*         ) pats_es) *)
  (*    in *)
  (*    wrap (M_Ecase( asym2, pats_es)) *)
  | M_Epure _ ->
     wrap e_
  | M_Ememop _ ->
     wrap e_
  | M_Eaction _ ->
     wrap e_
  | M_Eskip ->
     wrap e_
  | M_Eccall _ ->
     wrap e_
  | M_Erpredicate _ ->
     wrap e_
  | M_Elpredicate _ ->
     wrap e_
  | M_Einstantiate _ ->
     wrap e_

  | M_Elet( sym_or_pat, pe, e) ->
     wrap (M_Elet( sym_or_pat, pe, (taux e)))
  | M_Eif( asym2, e1, e2) ->
     wrap (M_Eif( asym2, taux e1, taux e2))
  | M_Eunseq es ->
     wrap (M_Eunseq (List.map taux es))
  | M_Ewseq( pat, e1, e2) -> 
     wrap (M_Ewseq( pat, taux e1, taux e2))
  | M_Esseq( pat, e1, e2) ->
     wrap (M_Esseq( pat, taux e1, taux e2))
  | M_Ebound e ->
     wrap (M_Ebound( taux e))
  | M_End es ->
     wrap (M_End (map taux es))
  (* | M_Eundef (uloc, undef) -> *)
  (*    wrap (M_Eundef (uloc, undef)) *)
  (* | M_Eerror (str, asym) -> *)
  (*    wrap (M_Eerror (str, asym)) *)
  | M_Erun(l, args) -> 
     let (label_sym, label_arg_syms_bts, label_body) = label in
     if not (Symbol.symbolEquality l label_sym) then 
       e
     else if not ((List.length label_arg_syms_bts) = (List.length args)) then
       failwith "M_Erun supplied wrong number of arguments"
     else
       let () = 
         Debug_ocaml.print_debug 1 [] 
           (fun () -> ("REPLACING LABEL " ^ Symbol.show_symbol l))
       in
       let arguments = (Lem_list.list_combine label_arg_syms_bts args) in
       let (M_Expr(_, annots2, e_)) = 
         (List.fold_right (fun ((spec_arg, spec_bt), expr_arg) body ->
              match expr_arg with
              | M_Pexpr (_, _, _, M_PEsym s) when Symbol.symbolEquality s spec_arg ->
                 body
              | _ ->
                 let pat = (M_Pattern (loc, [], M_CaseBase (Some spec_arg, spec_bt))) in
                 M_Expr(loc, [], (M_Elet (M_Pat pat, expr_arg, body)))
            ) arguments label_body)
       in
       (* this combines annotations *)
       M_Expr (loc, annots2 @ oannots, e_)


    


(* TODO: check about largs *)
let rec inline_label_labels_and_body to_inline to_keep body = 
   ((match to_inline with
  | [] -> (to_keep, body)
  | l :: to_inline' ->
     let to_inline' = 
       (map (fun (lname,arg_syms,lbody) -> 
           (lname,arg_syms,ib_texpr l lbody)
         ) to_inline')
     in
     let to_keep' = 
       (Pmap.map (fun def -> (match def with
         | M_Return _ -> def
         | M_Label(loc, lt, args, (largs : unit), lbody, annot) -> 
            M_Label(loc, lt, args, largs, (ib_texpr l lbody), annot)
         )) to_keep)
     in
     let body' = (ib_texpr l body) in
     inline_label_labels_and_body to_inline' to_keep' body'
  ))


let ib_fun_map_decl 
      (name1: symbol)
      (d : unit mu_fun_map_decl) 
    : unit mu_fun_map_decl=
   (try ((match d with
     | M_Proc( loc, rbt, arg_bts, body, label_defs) -> 
        let (to_keep, to_inline) =
          (let aux label def (to_keep, to_inline)=
             ((match def with
            | M_Return _ -> (Pmap.add label def to_keep, to_inline)
            | M_Label(_loc, lt1, args, (largs : unit), lbody, annot2) ->
               match get_label_annot annot2 with
               | Some (LAloop_break _)
               | Some (LAloop_continue _) 
               | Some (LAloop_body _) 
                 -> 
                  (to_keep, ((label, args, lbody) :: to_inline))
               | _ -> 
                  (Pmap.add label def to_keep, to_inline)
            )) 
          in
          Pmap.fold aux label_defs ((Pmap.empty Symbol.symbol_compare), []))
        in
        let (label_defs, body) = 
          (inline_label_labels_and_body to_inline to_keep body)
        in
        M_Proc( loc, rbt, arg_bts, body, label_defs)
     | _ -> d
     )) with | Failure error -> failwith (Symbol.show_symbol name1 ^ ": "  ^ error) )

let ib_fun_map (fmap1 : unit mu_fun_map) : unit mu_fun_map = 
   (Pmap.mapi ib_fun_map_decl fmap1)
  

let ib_globs (g : unit mu_globs) 
    : unit mu_globs= 
   ((match g with
  | M_GlobalDef(s, bt1, e) -> M_GlobalDef(s, bt1, e)
  | M_GlobalDecl (s, bt1) -> M_GlobalDecl (s, bt1)
  ))

let ib_globs_list (gs : unit mu_globs_list)
    : unit mu_globs_list= 
   (map (fun (sym1,g) -> (sym1, ib_globs g)) gs)


let ib_file file1 = 
   ({ file1 with mu_stdlib = (ib_fun_map file1.mu_stdlib)
             ; mu_globs = (ib_globs_list file1.mu_globs)
             ; mu_funs = (ib_fun_map file1.mu_funs)
  })

