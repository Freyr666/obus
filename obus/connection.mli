(*
 * connection.mli
 * --------------
 * Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implemtation of dbus.
 *)

(** Interface for dbus connection *)

type t
  (** Abstract type for a connection *)

type guid = Address.guid
    (** Unique identifier of a server *)

(** {6 Creation} *)

val of_transport : Transport.t -> bool -> t
  (** [of_transport transport private] create a dbus connection over
      the given transport. If [private] is false and a connection to
      the same server is already open, then it is used instead of
      [transport] *)

val of_addresses : Address.t list -> bool -> t
  (** [of_addresses addresses private] shorthand for obtaining
      transport and doing [of_transport] *)

(** {6 Sending messages} *)

(** Note: these functions take a complete message description, you may
    have a look at [Message] for easy creation of messages *)

type body = Val.value list
type message = Header.t * body

val send_message_sync : t -> message ->  message
  (** [send_message_sync connection message] send a message over a
      DBus connection.

      Note: the serial field of the header will always be filled
      automatically *)

val send_message_async : t -> message -> (message -> unit) -> unit
  (** same as send_message_sync but return immediatly and register a
      function for receiving the result *)

val send_message_no_reply : t -> message -> unit
  (** same as send_message_sync but do not expect a reply *)

(** {6 Dispatching} *)

val dispatch : t -> unit
  (** [dispatch bus] read and dispatch one message. If using threads
      [dispatch] do nothing. *)

type filter = Header.t -> body Lazy.t -> bool
  (** A filter is a function that take a message, do something with
      and return true if the message can be considered has "handled"
      or false if other filters must be called on it. *)

val add_filter : t -> filter -> unit
  (** [add_filter connection filter] add a filter to the connection.
      This filter will be called before all previously defined
      filter *)

val add_interface : t -> 'a Interface.t -> unit
  (** [add_interface connection interface] add handling of an
      interface to the connection.

      Method calls on this interface will be dispatched and the
      connection will also handle introspection *)

(** {6 Informations} *)

val transport : t -> Transport.t
  (** [transport connection] get the transport associated with a
      connection *)

val guid : t -> guid
  (** [guid connection] return the unique identifier of the server *)

(** {6 For autogenerated code} *)

(** Note: these functions are not intended to be used by the
    programs *)

type 'a reader = Header.t -> string -> int -> 'a
type writer = Header.byte_order -> string -> int -> int

val raw_send_message_sync : t -> Header.t -> writer -> 'a reader -> 'a
val raw_send_message_async : t -> Header.t -> writer -> unit reader -> unit
val raw_send_message_no_reply : t -> Header.t -> writer -> unit
val raw_add_filter : t -> bool reader -> unit
