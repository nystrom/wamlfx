open Emit
open Lower

type ctxt = Lower.ctxt

(* Helpers *)
let i32_type = W.NumType W.I32Type
let extern_ref = W.RefType W.ExternRefType

(* Memory *)

let compile_mem ctxt : int32 =
  Emit.lookup_intrinsic ctxt "mem" (fun _ ->
    let at = Prelude.region in
    emit_memory ctxt at 1l None
  )

let compile_mem_alloc ctxt : int32 =
  Emit.lookup_intrinsic ctxt "mem_alloc" (fun _ ->
    let at = Prelude.region in
    emit_func ctxt at [i32_type] [i32_type] (fun ctxt _ ->
      emit_instr ctxt at W.Unreachable
    )
  )

(* Text *)

let compile_text_new ctxt : int32 =
  Emit.lookup_intrinsic ctxt "text_new" (fun _ ->
    let at = Prelude.region in
    emit_func ctxt at [i32_type; i32_type] [extern_ref] (fun ctxt _ ->
      emit_instr ctxt at W.Unreachable
    )
  )

let compile_text_cpy ctxt : int32 =
  Emit.lookup_intrinsic ctxt "text_cpy" (fun _ ->
    let at = Prelude.region in
    emit_func ctxt at [extern_ref; i32_type; extern_ref; i32_type; i32_type] [] (fun ctxt _ ->
      emit_instr ctxt at W.Unreachable
    )
  )

let compile_text_cat ctxt : int32 =
  Emit.lookup_intrinsic ctxt "text_cat" (fun _ ->
    let at = Prelude.region in
    emit_func ctxt at [extern_ref; extern_ref] [extern_ref] (fun ctxt _ ->
      emit_instr ctxt at W.Unreachable
    )
  )

let compile_text_eq ctxt : int32 =
  Emit.lookup_intrinsic ctxt "text_eq" (fun _ ->
    let at = Prelude.region in
    emit_func ctxt at [extern_ref; extern_ref] [i32_type] (fun ctxt _ ->
      emit_instr ctxt at W.Unreachable
    )
  )

(* Application and combinators *)

let compile_func_apply arity ctxt =
  Emit.lookup_intrinsic ctxt ("func_apply" ^ string_of_int arity) (fun _ ->
    let at = Prelude.region in
    let args = List.init (arity + 1) (fun _ -> extern_ref) in
    emit_func ctxt at args [extern_ref] (fun ctxt _ ->
      emit_instr ctxt at W.Unreachable
    )
  )

let compile_load_arg ctxt at i arg0 argv_opt = ()
let compile_push_args ctxt at n f = ()
let compile_load_args ctxt at i j arg0 argv_opt = ()