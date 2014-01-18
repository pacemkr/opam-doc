(* Auto-generated from "index.atd" *)


type digest_t = Digest_t.digest_t

type t_value = Index_t.t_value = 
    Direct_path of (string * string)
  | Packed_module of (string * digest_t list)


val write_digest_t :
  Bi_outbuf.t -> digest_t -> unit
  (** Output a JSON value of type {!digest_t}. *)

val string_of_digest_t :
  ?len:int -> digest_t -> string
  (** Serialize a value of type {!digest_t}
      into a JSON string.
      @param len specifies the initial length
                 of the buffer used internally.
                 Default: 1024. *)

val read_digest_t :
  Yojson.Safe.lexer_state -> Lexing.lexbuf -> digest_t
  (** Input JSON data of type {!digest_t}. *)

val digest_t_of_string :
  string -> digest_t
  (** Deserialize JSON data of type {!digest_t}. *)

val write_t_value :
  Bi_outbuf.t -> t_value -> unit
  (** Output a JSON value of type {!t_value}. *)

val string_of_t_value :
  ?len:int -> t_value -> string
  (** Serialize a value of type {!t_value}
      into a JSON string.
      @param len specifies the initial length
                 of the buffer used internally.
                 Default: 1024. *)

val read_t_value :
  Yojson.Safe.lexer_state -> Lexing.lexbuf -> t_value
  (** Input JSON data of type {!t_value}. *)

val t_value_of_string :
  string -> t_value
  (** Deserialize JSON data of type {!t_value}. *)

