(*
 * auth.ml
 * -------
 * Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implemtation of dbus.
 *)

open ThreadImplem

open Unix

type data = string
type guid = string

type client_state =
  [ `Waiting_for_data
  | `Waiting_for_ok
  | `Waiting_for_reject ]

type client_command =
  [ `Auth of string * data
  | `Cancel
  | `Begin
  | `Data of data
  | `Error of string ]

type server_command =
    [ `Rejected of string list
    | `OK of guid
    | `Data of data
    | `Error of string ]

type mechanism_return =
  | Continue of data
  | OK of data
  | Error of string

class type mechanism =
object
  method init : mechanism_return
  method data : data -> mechanism_return
  method shutdown : unit
end

class virtual immediate =
object
  method virtual init : mechanism_return
  method data (_ : data) = Error("no data expected for this mechanism")
  method shutdown = ()
end

(* Predefined mechanisms *)

class external_mech = object
  inherit immediate
  method init = OK(string_of_int (Unix.getuid ()))
end

type maker = string * (unit -> mechanism)
let makers = Protected.make [("EXTERNAL", fun () -> new external_mech)]
let register_mechanism name m = Protected.update (fun l -> (name, m) :: l) makers

(* The protocol state machine for the client *)

type client_machine_state = client_state * mechanism * maker list
type client_machine_transition =
  | ClientTransition of (client_command * client_machine_state)
  | ClientFinal of guid
  | ClientFailure of string

(* Transitions *)

let rec find_mechanism = function
  | [] -> None
  | (name, create_mech) :: mechs ->
      try
        let mech = create_mech () in
          match mech#init with
            | Continue(resp) -> Some(`Auth(name, resp), (`Waiting_for_data, mech, mechs))
            | OK(resp)       -> Some(`Auth(name, resp), (`Waiting_for_ok,   mech, mechs))
            | Error(_)       -> find_mechanism mechs
      with
          _ -> find_mechanism mechs

let client_transition (state, mech, mechs) cmd = match state, cmd with
  | `Waiting_for_data, `Data(data) ->
      ClientTransition(
        match mech#data data with
          | Continue(resp) -> `Data(resp), (`Waiting_for_data, mech, mechs)
          | OK(resp)       -> `Data(resp), (`Waiting_for_ok,   mech, mechs)
          | Error(msg)     -> `Error(msg), (`Waiting_for_data, mech, mechs))

  | _, `Rejected(supported_mechanisms) ->
      mech#shutdown;
      begin match find_mechanism
        (List.filter (fun (name, _) -> List.mem name supported_mechanisms) mechs)
      with
        | Some(x) -> ClientTransition(x)
        | None    -> ClientFailure "no working mechanism found"
      end

  | `Waiting_for_reject, _ -> ClientFailure "protocol error"

  | _, `OK(guid) -> ClientFinal(guid)

  | `Waiting_for_ok, `Data _
  | _, `Error _ -> ClientTransition(`Cancel, (`Waiting_for_reject, mech, mechs))

let client_machine_exec recv send =
  let rec aux state =
    try
      match client_transition state (recv ()) with
        | ClientFinal(guid) -> send `Begin; Some(guid)
        | ClientTransition(cmd, state) -> send cmd; aux state
        | ClientFailure(_) -> None
    with
      | Failure _ ->
          send (`Error "parsing error");
          aux state
  in aux

let hexstring_of_data buf str =
  String.iter (fun c -> Printf.bprintf buf "%02x" (int_of_char c)) str

let marshal_client_command buf = function
  | `Auth(mechanism, data) ->
      Buffer.add_string buf "AUTH ";
      Buffer.add_string buf mechanism;
      Buffer.add_char buf ' ';
      hexstring_of_data buf data
  | `Cancel -> Buffer.add_string buf "CANCEL"
  | `Begin -> Buffer.add_string buf "BEGIN"
  | `Data(data) ->
      Buffer.add_string buf "DATA ";
      hexstring_of_data buf data
  | `Error(message) ->
      Buffer.add_string buf "ERROR ";
      Buffer.add_string buf message

let launch transport =
  let read =
    if Log.Debug.authentification
    then
      (fun buf count -> let count = transport.Transport.recv buf 0 count in
         DEBUG("received: %s" (String.sub buf 0 count));
         count)
    else
      (fun buf count -> transport.Transport.recv buf 0 count)
  in
  let lexbuf = Lexing.from_function read in

  let send command =
    let buf = Buffer.create 42 in
      marshal_client_command buf command;
      Buffer.add_string buf "\r\n";
      let line = Buffer.contents buf in
      let len = String.length line in
        DEBUG("sending: %s" line);
        assert (transport.Transport.send line 0 len = len)

  and recv () =
    AuthLexer.command lexbuf
  in

    match find_mechanism (Protected.get makers) with
      | Some(cmd, state) ->
          assert (transport.Transport.send "\x00" 0 1 = 1);
          send cmd;
          client_machine_exec recv send state
      | None -> None
