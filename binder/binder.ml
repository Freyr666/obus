(*
 * binder.ml
 * ---------
 * Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, a ocaml implemtation of dbus.
 *)

module MakeMap(L : Language.S) =
struct
  open L

  let xml_fnames = ref []
  let skipped_interfaces = ref []
  let permit_default = ref false
  let prefix = ref ["org\\.freedesktop\\."]
  let out = ref "out.obus.xml"
  let flat = ref false

  let args = [
    ("-skip", Arg.String (fun s -> skipped_interfaces := s :: !skipped_interfaces), "skip interfaces matching regexp");
    ("-allow-default", Arg.Set permit_default, "do not skip default interfaces");
    ("-o", Arg.Set_string out, "output file (default = out.mli)");
    ("-prefix", Arg.String (fun p -> prefix := p :: !prefix), "prefix to delete from interface names");
    ("-flat", Arg.Set flat, "do not include interfaces in each other")
  ] @ L.args_mapper

  let make_args args =
    List.map (function
                | DBus.Arg(name, typ) -> Lmap.Arg((name, L.correct_arg_name name),
                                                  typ,
                                                  default_type typ)) args

  let make_interf defs =
    List.map begin function
      | DBus.Method(dbus_name, ins, outs) ->
          Lmap.Method((dbus_name, correct_method_name dbus_name),
                      make_args ins,
                      make_args outs)
      | DBus.Signal(dbus_name, args) ->
          Lmap.Signal((dbus_name, correct_method_name dbus_name),
                      make_args args)
    end defs

  let rec make_tree dbus_names lang_names (DBus.Node(interfs)) =
    Lmap.Node begin List.map begin fun (dbus_name, defs, sons) ->
      let dbus_names = dbus_name :: dbus_names in
      let complete_dbus_name = Util.rjoin "." dbus_names in
      let lang_name = correct_module_name dbus_name in
      let lang_names = lang_name :: lang_names in
        ((complete_dbus_name, lang_name),
         make_interf defs,
         make_tree dbus_names lang_names sons)
    end interfs end

  let rec make_flat dbus_names (DBus.Node(interfs)) =
    Lmap.Node begin List.flatten begin List.map begin fun (dbus_name, defs, sons) ->
      let dbus_names = dbus_name :: dbus_names in
      let complete_dbus_name = Util.rjoin "." dbus_names in
      let lang_name = L.correct_module_name (Util.rjoin "_" dbus_names) in
        ((complete_dbus_name, lang_name),
         make_interf defs,
         Lmap.Node []) :: (fun (Lmap.Node(l)) -> l) (make_flat dbus_names sons)
    end interfs end end

  let main () =
    Arg.parse args
      (fun s -> xml_fnames := s :: !xml_fnames)
      "generate a caml module signature from a introspection data";
    if not !permit_default
    then skipped_interfaces := !skipped_interfaces @ ["org\\.freedesktop\\.DBus.*"];

    let filters = List.map Str.regexp !skipped_interfaces in
    let prefix = List.map Str.regexp !prefix in
    let accept name = not (List.exists (fun r -> Str.string_match r name 0) filters) in
    let rec delete_prefix name = function
      | [] -> name
      | prefix :: prefixes ->
          if Str.string_match prefix name 0
          then Str.replace_first prefix "" name
          else delete_prefix name prefixes
    in
    let dbus_interfaces = List.fold_left
      (fun acc (name, defs) -> if accept name then DBus.add (delete_prefix name prefix) defs acc else acc)
      (DBus.Node [])
      (List.flatten (List.map (fun fname -> Util.with_open_in fname
                                 (fun ch -> DBus.from_xml
                                    (Util.parse_xml (Lexing.from_channel ch)))) !xml_fnames)) in
    let map =
      Lmap.Mapping(L.name,
                   if !flat
                   then make_flat [] dbus_interfaces
                   else make_tree [] [] dbus_interfaces)
    in
      Util.with_open_out !out begin fun ch ->
        Printf.fprintf ch "<!-- File generated with %s -->\n" (Filename.basename (Sys.argv.(0)));
        output_string ch (Xml.to_string_fmt (Lmap.to_xml string_of_type map))
      end
end

module MakeGen(L : Language.S) =
struct
  let main () = ()
end