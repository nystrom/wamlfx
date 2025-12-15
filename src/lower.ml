open Emit

module T = Type
module W = Emit.W
module E = Env


(* Locations *)

type null = Null | Nonull

type loc =
  | PreLoc of int32
  | LocalLoc of int32
  | GlobalLoc of int32
  | ClosureLoc of null * int32 * int32 * int32 (* fldidx, localidx, typeidx *)

type func_loc = {funcidx : int32; typeidx : int32; arity : int}

let as_local_loc = function LocalLoc idx -> idx | _ -> assert false
let as_global_loc = function GlobalLoc idx -> idx | _ -> assert false


(* Representations *)

type rep =
  | DropRep                (* value never used *)
  | BlockRep of null       (* like Boxed, but empty tuples are suppressed *)
  | BoxedRep of null       (* concrete boxed representation *)
  | BoxedAbsRep of null    (* abstract boxed representation *)
  | UnboxedRep of null     (* representation with unboxed type or concrete ref types *)
  | UnboxedLaxRep of null  (* like Unboxed, but Int may have junk high bit *)

let null_rep = function
  | BlockRep n | BoxedRep n | BoxedAbsRep n | UnboxedRep n | UnboxedLaxRep n -> n
  | DropRep -> assert false

(* Configurable *)
let boxed_if flag null = if !flag then BoxedRep null else UnboxedRep null
let local_rep () = boxed_if Flags.box_locals Null    (* values stored in locals *)
let clos_rep () = boxed_if Flags.box_locals Nonull   (* values stored in closures *)
let global_rep () = boxed_if Flags.box_globals Null  (* values stored in globals *)
let struct_rep () = boxed_if Flags.box_modules Nonull (* values stored in structs *)
let tmp_rep () = boxed_if Flags.box_temps Null       (* values stored in temps *)
let pat_rep () = boxed_if Flags.box_scrut Nonull     (* values fed into patterns *)

(* Non-configurable *)
let ref_rep = BoxedAbsRep Null      (* expecting a reference *)
let rigid_rep = UnboxedRep Nonull   (* values produced or to be consumed *)
let lax_rep = UnboxedLaxRep Nonull  (* lax ints produced or consumed *)
let field_rep = BoxedAbsRep Nonull  (* values stored in fields *)
let arg_rep = BoxedAbsRep Nonull    (* argument and result values *)
let unit_rep = BlockRep Nonull      (* nothing on stack *)

let loc_rep = function
  | PreLoc _ -> rigid_rep
  | GlobalLoc _ -> global_rep ()
  | LocalLoc _ -> local_rep ()
  | ClosureLoc _ -> clos_rep ()


let max_func_arity () = if !Flags.headless then 4 else 12

module Clos_indices = struct
  let arity = 0l
  let code = 1l
  let env_start = 2l
end


(* Environment *)

type data_con = {tag : int32; typeidx : int32; arity : int}
type data = (string * data_con) list
type env = (loc * func_loc option, data, loc * func_loc option, unit) E.env
type scope = PreScope | LocalScope | GlobalScope

let make_env () =
  let env = ref E.empty in
  List.iteri (fun i (x, _) ->
    env := E.extend_val !env Source.(x @@ Prelude.region)
      (PreLoc (Int32.of_int i), None)
  ) Prelude.vals;
  env

let scope_rep = function
  | PreScope -> rigid_rep
  | LocalScope -> local_rep ()
  | GlobalScope -> global_rep ()


(* Compilation context *)

type ctxt_ext =
  { envs : (scope * env ref) list;
    texts : int32 Env.Map.t ref;
    data : int32 ref;
  }
type ctxt = ctxt_ext Emit.ctxt

let make_ext_ctxt () : ctxt_ext =
  { envs = [(PreScope, make_env ())];
    texts = ref Env.Map.empty;
    data = ref (-1l);
  }
let make_ctxt () : ctxt = Emit.make_ctxt (make_ext_ctxt ())

let enter_scope ctxt scope : ctxt =
  {ctxt with ext = {ctxt.ext with envs = (scope, ref E.empty) :: ctxt.ext.envs}}

let current_scope ctxt : scope * env ref =
  List.hd ctxt.ext.envs


(* Lowering types *)

let lower_ref null ht =
  W.(RefType ExternRefType)

let abs = 0
let absref = W.(RefType ExternRefType)

let lower_value_type ctxt at rep t : W.value_type =
  match T.norm t with
  | T.Bool | T.Byte | T.Int -> W.NumType W.I32Type
  | T.Float -> W.NumType W.F64Type
  | _ -> W.RefType W.ExternRefType

let lower_con_type ctxt at ts = 0l

let lower_var_type ctxt at t = 0l

let lower_anyclos_type ctxt at = 0l

let lower_func_type ctxt at arity = 0l, 0l

let lower_clos_type ctxt at arity flds = 0l, 0l, 0l

let lower_param_types ctxt at arity : W.value_type list * int32 option =
  List.init arity (fun _ -> absref), None

let lower_block_type ctxt at rep t : W.block_type =
  W.ValBlockType (Some (lower_value_type ctxt at rep t))


(* Lowering signatures *)

let lower_sig_type ctxt at s : W.value_type * int32 =
  absref, 0l

let lower_str_type ctxt at str : W.value_type * int32 =
  absref, 0l

let lower_fct_type ctxt at s1 s2 : int32 * int32 =
  0l, 0l

let lower_fct_clos_type ctxt at s1 s2 flds : int32 * int32 * int32 =
  0l, 0l, 0l


(* Closure environments *)

let lower_clos_env ctxt at vars rec_xs
  : unit list * (string * T.typ * int) list =
  [], []