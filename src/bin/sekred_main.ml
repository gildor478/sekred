(******************************************************************************)
(* sekred: Password manager for automatic installation.                       *)
(*                                                                            *)
(* Copyright (C) 2013, Sylvain Le Gall                                        *)
(*                                                                            *)
(* This library is free software; you can redistribute it and/or modify it    *)
(* under the terms of the GNU Lesser General Public License as published by   *)
(* the Free Software Foundation; either version 2.1 of the License, or (at    *)
(* your option) any later version, with the OCaml static compilation          *)
(* exception.                                                                 *)
(*                                                                            *)
(* This library is distributed in the hope that it will be useful, but        *)
(* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY *)
(* or FITNESS FOR A PARTICULAR PURPOSE. See the file COPYING for more         *)
(* details.                                                                   *)
(*                                                                            *)
(* You should have received a copy of the GNU Lesser General Public License   *)
(* along with this library; if not, write to the Free Software Foundation,    *)
(* Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA              *)
(******************************************************************************)

open Sekred

let () =
  let password =
    ref (fun () ->
           failwith "You need to set --password=... for this action.")
  in
  let vardir = ref default_conf.vardir in
  let uid = ref None in
  let auto_enable = ref false in
  let args =
    [
      "--vardir",
      Arg.String
        (fun fn -> vardir := fn),
      "fn Set sekred vardir.";

      "--password",
      Arg.String
        (fun str ->
           password := fun () -> str),
      "str Password to set.";

      "--password_fn",
      Arg.String
        (fun fn ->
           let chn = open_in fn in
           let str = input_line chn in
             close_in chn;
             password := fun () -> str),
      "fn Read password from file.";

      "--uid",
      Arg.String
        (fun id_str ->
           let id =
             try
               int_of_string id_str
             with Failure _ ->
               begin
                 try
                   (Unix.getpwnam id_str).Unix.pw_uid
                 with Not_found ->
                   failwith
                     (Printf.sprintf
                        "Unable to find user '%s'."
                        id_str)
               end
           in
             uid := Some id),
      "uid User id to act on (may need to be root).";

      "--auto_enable",
      Arg.Set auto_enable,
      " Enable the user automatically if needed."
    ]
  in
  let lst = ref [] in
  let usage_msg =
      Printf.sprintf "\
sekred v%s

Command:

  sekred [options*] get domain
  sekred [options*] delete domain
  sekred [options*] set domain
  sekred [options*] exists domain
  sekred [options*] list
  sekred [options*] enable
  sekred [options*] disable
  sekred [options*] is_enabled
  sekred [options*] init

Options:\n" SekredConf.version
  in
  let () =
    Arg.parse
      (Arg.align args)
      (fun str -> lst := str :: !lst)
      usage_msg
  in

  let conf = {default_conf with vardir = !vardir} in

  let t need_enable =
    let t = Sekred.create ~conf ?uid:!uid () in
      if !auto_enable && need_enable then
        enable t;
      t
  in

    match List.rev !lst with
      | ["get"; domain] ->
          print_endline (Sekred.get (t true) domain)
      | ["delete"; domain] ->
          Sekred.delete (t false) domain
      | ["set"; domain] ->
          Sekred.set (t true) domain (!password ())
      | ["exists"; domain] ->
          if not (List.mem domain (Sekred.list (t false))) then
            exit 1
      | ["list"] ->
          List.iter print_endline (Sekred.list (t false))
      | ["check"] ->
          let lst = Sekred.check ~conf () in
          List.iter prerr_endline lst;
          if lst <> [] then exit 1
      | ["enable"] ->
          enable (t false)
      | ["disable"] ->
          disable (t false)
      | ["is_enabled"] ->
          if is_enabled (t false) then exit 0 else exit 1
      | ["init"] ->
          Sekred.init ~conf ()
      | _ ->
          Arg.usage (Arg.align args) usage_msg;
          exit 2
