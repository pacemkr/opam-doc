(* Auto-generated from "index.atd" *)


type digest_t = Digest_t.digest_t

type t_value = 
    Direct_path of (string * string)
  | Packed_module of (string * digest_t list)

