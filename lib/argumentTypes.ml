open Locations
module BT = BaseTypes
module IT = IndexTerms
module Req = Request
module LC = LogicalConstraints
module LAT = LogicalArgumentTypes

type 'i t =
  | Computational of (Sym.t * BT.t) * info * 'i t
  | Ghost of (Sym.t * BT.t) * info * 'i t
  | L of 'i LAT.t

let mComputational (name, bound, info) t = Computational ((name, bound), info, t)

let mComputationals t = List.fold_right mComputational t

let rec subst i_subst (substitution : _ Subst.t) at =
  match at with
  | Computational ((name, bt), info, t) ->
    let name, t = suitably_alpha_rename i_subst substitution.relevant name t in
    Computational ((name, bt), info, subst i_subst substitution t)
  | Ghost ((name, bt), info, t) ->
    let name, t = suitably_alpha_rename i_subst substitution.relevant name t in
    Ghost ((name, bt), info, subst i_subst substitution t)
  | L t -> L (LAT.subst i_subst substitution t)


and alpha_rename i_subst s t =
  let s' = Sym.fresh_same s in
  (s', subst i_subst (IT.make_rename ~from:s ~to_:s') t)


and suitably_alpha_rename i_subst syms s t =
  if Sym.Set.mem s syms then
    alpha_rename i_subst s t
  else
    (s, t)


let simp i_subst simp_i simp_it simp_lc simp_re =
  let rec aux = function
    | Computational ((s, bt), info, t) ->
      let s, t = alpha_rename i_subst s t in
      Computational ((s, bt), info, aux t)
    | Ghost ((s, bt), info, t) ->
      let s, t = alpha_rename i_subst s t in
      Ghost ((s, bt), info, aux t)
    | L lt -> L (LAT.simp i_subst simp_i simp_it simp_lc simp_re lt)
  in
  aux


let pp i_pp ft =
  let open Pp in
  let rec aux = function
    | Computational ((name, bt), _info, t) ->
      let op = if !unicode then utf8string "\u{03A0}" else !^"AC" in
      group (op ^^^ typ (Sym.pp name) (BT.pp bt) ^^ dot) :: aux t
    | Ghost ((name, bt), _info, t) ->
      let op = if !unicode then utf8string "\u{2200}" else !^"AL" in
      group (op ^^^ typ (Sym.pp name) (BT.pp bt) ^^ dot) :: aux t
    | L t -> LAT.pp_aux i_pp t
  in
  flow (break 1) (aux ft)


let rec get_return = function
  | Computational (_, _, ft) -> get_return ft
  | Ghost (_, _, ft) -> get_return ft
  | L t -> LAT.get_return t


let rec get_lat = function
  | Computational (_, _, ft) -> get_lat ft
  | Ghost (_, _, ft) -> get_lat ft
  | L t -> t


let rec get_computational = function
  | Computational (sbt, _, ft) -> sbt :: get_computational ft
  | Ghost (_, _, ft) -> get_computational ft
  | L _ -> []


let rec get_ghost = function
  | Computational (_, _, ft) -> get_ghost ft
  | Ghost (sbt, _, ft) -> sbt :: get_ghost ft
  | L _ -> []


let count_computational at = List.length (get_computational at)

let count_ghost at = List.length (get_ghost at)

module LRT = LogicalReturnTypes
module RT = ReturnTypes

let alpha_unique ss =
  let rename_if ss = suitably_alpha_rename RT.subst ss in
  let rec f ss at =
    match at with
    | Computational ((name, bt), info, t) ->
      let name, t = rename_if ss name t in
      let t = f (Sym.Set.add name ss) t in
      Computational ((name, bt), info, t)
    | Ghost ((name, bt), info, t) ->
      let name, t = rename_if ss name t in
      let t = f (Sym.Set.add name ss) t in
      Ghost ((name, bt), info, t)
    | L t -> L (LAT.alpha_unique ss t)
  in
  f ss


let of_rt (rt : RT.t) (rest : 'i LAT.t) : 'i t =
  let (RT.Computational ((name, t), info, lrt)) = rt in
  Computational ((name, t), info, L (LAT.of_lrt lrt rest))


let rec map (f : 'i -> 'j) (at : 'i t) : 'j t =
  match at with
  | Computational (bound, info, at) -> Computational (bound, info, map f at)
  | Ghost (bound, info, at) -> Ghost (bound, info, map f at)
  | L t -> L (LAT.map f t)


type ift = IndexTerms.t t

type ft = ReturnTypes.t t

type lt = False.t t

type lemmat = LogicalReturnTypes.t t

open Cerb_frontend.Pp_ast

let dtree dtree_i =
  let rec aux = function
    | Computational ((s, _bt), _, lat) ->
      Dnode (pp_ctor "Computational", [ Dleaf (Sym.pp s); aux lat ])
    | Ghost ((s, _bt), _, lat) -> Dnode (pp_ctor "Ghost", [ Dleaf (Sym.pp s); aux lat ])
    | L l -> LAT.dtree dtree_i l
  in
  aux
