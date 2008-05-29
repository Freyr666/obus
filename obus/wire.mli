(*
 * wire.mli
 * --------
 * Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implemtation of dbus.
 *)

(** Used by autogenerated interfaces *)

type ptr = int
    (** A position in a buffer *)

type buffer = string
    (** A buffer containing a marshaled value *)

exception Content_error of string
  (** This exception must be raised by convertion functions if a value
      is invalid *)

(** Exceptions that can be raised by auto-generated
    marshaling/unmarshaling functions *)

module Reading : sig

  (** Consistency errors, the message is an invalid dbus message *)

  exception Array_too_big
    (** The marshaled representation of an array is bigger than
        allowed by the dbus specification *)
  exception Invalid_array_size
    (** The anounced size of an array does not match is real size *)
  exception Invalid_message_size
    (** The anounced size of the message is incorrent *)
  exception Invalid_signature
    (** A marshaled signature is invalid *)

  (** Content errors *)

  exception Unexpected_signature
    (** The signature for a variant does not correspond to what we
        expect *)
  exception Unexpected_key
    (** The key for a variant is invalid *)
end

module Writing : sig
  exception Array_too_big
    (** The marhaled representation of an array is too big to be
        sent *)
end

val native_byte_order : unit -> int

(** All the following functions assumes that there is enough space in
    the buffer to read/write something.

    The names of functions for reading/writing are of the form
    dbus-type_caml-type *)

module type Writer = sig
  type 'a t = buffer -> ptr -> 'a -> unit
  val int_int16 : int t
  val int_int32 : int t
  val int_int64 : int t
  val int_uint16 : int t
  val int_uint32 : int t
  val int_uint64 : int t
  val int32_int32 : int32 t
  val int64_int64 : int64 t
  val int32_uint32 : int32 t
  val int64_uint64 : int64 t
  val float_double : float t
end

module type Reader = sig
  type 'a t = buffer -> ptr -> 'a
  val int_int16 : int t
  val int_int32 : int t
  val int_int64 : int t
  val int_uint16 : int t
  val int_uint32 : int t
  val int_uint64 : int t
  val int32_int32 : int32 t
  val int64_int64 : int64 t
  val int32_uint32 : int32 t
  val int64_uint64 : int64 t
  val float_double : float t
end

module LEWriter : Writer
module BEWriter : Writer
module LEReader : Reader
module BEReader : Reader

val string_match : buffer -> ptr -> string -> int -> bool
  (** [string_match buffer ptr str len] compare the [len] first char
      of [str] with the content of [buffer] starting at [ptr] *)

val realloc_buffer : buffer -> ptr -> buffer
  (** [realloc buffer n] return a new buffer bigger than [buffer] with
      same first [n] bytes *)
