(*
 * oBus_transport.ml
 * -----------------
 * Copyright : (c) 2009, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implementation of D-Bus.
 *)

open Unix
open Printf
open Lwt
open OBus_address

type t = {
  recv : unit -> OBus_message.t Lwt.t;
  send : OBus_message.t -> unit Lwt.t;
  capabilities : OBus_auth.capability list;
  shutdown : unit -> unit Lwt.t;
}

let make ~recv ~send ?(capabilities=[]) ~shutdown () = {
  recv = recv;
  send = send;
  capabilities = capabilities;
  shutdown = shutdown;
}

let recv t = t.recv ()
let send t message = t.send message
let capabilities t = t.capabilities
let shutdown t = t.shutdown ()

let socket ?(capabilities=[]) fd =
  if List.mem `Unix_fd capabilities then
    let reader = OBus_wire.reader fd
    and writer = OBus_wire.writer fd in
    { recv = (fun _ -> OBus_wire.read_message_with_fds reader);
      send = (fun msg -> OBus_wire.write_message_with_fds writer msg);
      capabilities = capabilities;
      shutdown = (fun _ ->
                    Lwt_unix.shutdown fd SHUTDOWN_ALL;
                    Lwt_unix.close fd;
                    return ()) }
  else
    let ic = Lwt_io.make ~mode:Lwt_io.input (Lwt_unix.read fd)
    and oc = Lwt_io.make ~mode:Lwt_io.output (Lwt_unix.write fd) in
    { recv = (fun _ -> OBus_wire.read_message ic);
      send = (fun msg -> OBus_wire.write_message oc msg);
      capabilities = capabilities;
      shutdown = (fun _ ->
                    lwt () = Lwt_io.close ic <&> Lwt_io.close oc in
                    Lwt_unix.shutdown fd SHUTDOWN_ALL;
                    Lwt_unix.close fd;
                    return ()) }

let loopback () =
  let mvar = Lwt_mvar.create_empty () in
  { recv = (fun _ -> Lwt_mvar.take mvar);
    send = (fun m -> Lwt_mvar.put mvar m);
    capabilities = [`Unix_fd];
    shutdown = return }

let make_socket domain typ addr =
  let fd = Lwt_unix.socket domain typ 0 in
  (try Unix.set_close_on_exec (Lwt_unix.unix_file_descr fd) with _ -> ());
  try_lwt
    lwt () = Lwt_unix.connect fd addr in
    return fd
  with exn ->
    Lwt_unix.close fd;
    fail exn

let string_of_socket_params domain typ addr =
  Printf.sprintf "domain=%s typ=%s addr=%s"
    (match domain with
       | PF_UNIX -> "unix"
       | PF_INET -> "inet"
       | PF_INET6 -> "inet6")
    (match typ with
       | SOCK_STREAM -> "stream"
       | SOCK_DGRAM -> "dgram"
       | SOCK_RAW -> "raw"
       | SOCK_SEQPACKET -> "seqpacket")
    (match addr with
       | ADDR_UNIX path -> sprintf "unix(%s)" path
       | ADDR_INET(addr, port) -> sprintf "inet(%s,%d)" (string_of_inet_addr addr) port)

let of_addresses ?(capabilities=[]) ?mechanisms addresses =
  let rec try_one domain typ addr fallback x =
    try_lwt
      lwt fd = make_socket domain typ addr in
      Lwt_unix.write fd "\x00" 0 1 >>= function
        | 0 ->
            fail (OBus_auth.Auth_failure "failed to send the initial null byte")
        | 1 ->
            lwt guid, capabilities =
              OBus_auth.Client.authenticate
                ~capabilities:(List.filter (function `Unix_fd -> domain = PF_UNIX) capabilities)
                ?mechanisms
                ~stream:(OBus_auth.stream_of_fd fd)
                ()
            in
            return (guid, socket ~capabilities fd)
        | n ->
            assert false
    with
      | OBus_auth.Auth_failure msg ->
          Log#error "authentication failed for address: domain=%s: %s"
            (string_of_socket_params domain typ addr) msg;
          fallback x
      | exn ->
          Log#exn exn "transport creation failed for address: %s"
            (string_of_socket_params domain typ addr);
          fallback x
  in
  let rec aux = function
    | [] ->
        fail (Failure "no working D-Bus address found")
    | { OBus_address.address = address } :: rest ->
        match address with
          | Unix_path path ->
              try_one PF_UNIX SOCK_STREAM (ADDR_UNIX(path))
                aux rest

          | Unix_abstract path ->
              try_one PF_UNIX SOCK_STREAM (ADDR_UNIX("\x00" ^ path))
                aux rest

          | Unix_tmpdir _ ->
              Log#error "unix tmpdir can only be used as a listening address";
              aux rest

          | Tcp { tcp_host = host; tcp_port = port; tcp_family = family } ->
              let opts = [AI_SOCKTYPE SOCK_STREAM] in
              let opts = match family with
                | Some `Ipv4 -> AI_FAMILY PF_INET :: opts
                | Some `Ipv6 -> AI_FAMILY PF_INET6 :: opts
                | None -> opts in
              let rec try_all = function
                | [] -> aux rest
                | ai :: ais -> try_one ai.ai_family ai.ai_socktype ai.ai_addr try_all ais
              in
              try_all (getaddrinfo host port opts)

          | Autolaunch ->
              lwt addresses =
                try_lwt
                  lwt uuid = Lazy.force OBus_info.machine_uuid in
                  lwt line =
                    try_lwt
                      Lwt_process.pread_line ("dbus-launch",
                                              [|"dbus-launch"; "--autolaunch"; OBus_uuid.to_string uuid; "--binary-syntax"|])
                    with exn ->
                      Log#error "autolaunch failed: %s" (OBus_util.string_of_exn exn);
                      fail exn
                  in
                  let line = try String.sub line 0 (String.index line '\000') with _ -> line in
                  return (OBus_address.of_string line)
                with exn ->
                  return []
              in
              aux (addresses @ rest)

          | _ ->
              aux rest
  in
  aux addresses
