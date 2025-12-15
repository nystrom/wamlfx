open Source
open Emit

module W = Emit.W

exception NYI of Source.region * string

let compile_prog (p : Syntax.prog) : W.module_ =
  let ctxt = Lower.make_ctxt () in
  let start_idx = emit_func ctxt p.at [] [] (fun _ _ -> ()) in
  emit_start ctxt p.at start_idx;
  Emit.gen_module ctxt p.at
