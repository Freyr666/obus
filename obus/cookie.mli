(*
 * cookie.mli
 * ----------
 * Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implemtation of dbus.
 *)

(** Asynchronous recption of messages *)

(** A cookie is used to make an asynchronous method call and retreive
    the reply content later. It is like a [lazy] value. The value of
    the cookie became accessible as the reply is arrived. *)

type 'a t
  (** A non retreived message content *)

val send_message_with_cookie : Connection.t -> Connection.send_message -> Connection.recv_message t
  (** [send_message_sync connection message] send a message over a
      DBus connection, and return immediatly a cookie for getting back
      the result later *)

val get : 'a t -> 'a
  (** [get cookie] get the value associated with a cookie,
      eventually waiting for it *)

val is_ready : 'a t -> bool
  (** [is_ready cookie] return true is the cookie is evaluated *)

val get_if_ready : 'a t -> 'a option
  (** [get_if_ready cookie] return Some(v) where v is the value of
      [cookie] if it is ready, of None if not *)

(**/**)

val raw_send_message_with_cookie : Connection.t -> Header.send -> Connection.writer -> 'a Connection.reader -> 'a t
