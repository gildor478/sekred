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

open Unix

type filename = string

type conf =
    {
      vardir: filename;
      stat: filename -> Unix.stats;
      chmod: filename -> int -> unit;
      chown: filename -> int -> int -> unit;
    }

let default_conf =
  {
    vardir = SekredConf.vardir;
    stat = Unix.stat;
    chmod = Unix.chmod;
    chown = Unix.chown;
  }

type t =
    {
      conf: conf;
      uid: int;
    }

let gid_of_group group =
  try
    Unix.getgrnam group
  with
    | Unix.Unix_error (error, str1, str2) ->
        failwith
          (Printf.sprintf "%s(%s): %s"
             str1 str2 (Unix.error_message error))
    | Not_found ->
        failwith
          (Printf.sprintf "Group %s doesn't exist."
          group)

let name_of_uid uid =
  try
    (Unix.getpwuid uid).Unix.pw_name
  with Not_found ->
    string_of_int uid

let ls_full dn = Array.map (Filename.concat dn) (Sys.readdir dn)

let domainsdir conf = Filename.concat conf.vardir "domains"

let user_domainsdir t =
  Filename.concat (domainsdir t.conf) (Printf.sprintf "%08d" t.uid)

let to_filename t domain =
  Filename.concat (user_domainsdir t) domain

let has_access t domain =
  try
    let chn = open_in (to_filename t domain) in
      close_in chn;
      true
  with Sys_error _ ->
    false

let exists t domain =
  let fn = to_filename t domain in
    Sys.file_exists fn && not (Sys.is_directory fn)

let set t domain password =
  let fix_right () =
    if exists t domain then begin
      let fn = to_filename t domain in
      let st = t.conf.stat fn in
      t.conf.chown fn t.uid st.Unix.st_gid;
      t.conf.chmod fn 0o600
    end
  in
  let () =
    if exists t domain && not (has_access t domain) then
      failwith
        (Printf.sprintf
           "Access denied to '%s'"
           domain)
  in
  let chn_out =
    open_out_gen
      [Open_wronly; Open_creat; Open_trunc]
      0o600
      (to_filename t domain)
  in
  let final () =
    close_out chn_out;
    fix_right ()
  in
    try
      output_string chn_out password;
      final ()
    with e ->
      begin
        try
          final ()
        with e ->
          ()
      end;
      raise e

let rng =
  let rng_opt = ref None in
    fun () ->
      match !rng_opt with
        | Some rng ->
            rng
        | None ->
            begin
              (* Random seed of OCaml is time based, an attacker could easily
               * guess this from the timestamp of the file we will create.
               * Use a better seed coming from /dev/random (Linux-only).
               *)
              let seed =
                let chn = open_in "/dev/random" in
                let final () =
                  close_in chn
                in
                  try
                    let res =
                      [|
                        input_binary_int chn;
                        input_binary_int chn;
                        Unix.getpid ();
                      |]
                    in
                      final ();
                      res
                  with e ->
                    final ();
                    raise e
              in
              let rng = Random.State.make seed in
                rng_opt := Some rng;
                rng
            end

let pwgen () =
  let symbol =
    [|
      'a'; 'b'; 'c'; 'd'; 'e'; 'f'; 'g'; 'h'; 'i'; 'j'; 'k';
      'm'; 'n'; 'o'; 'p'; 'q'; 'r'; 's'; 't'; 'u'; 'w'; 'y'; 'z';
      'A'; 'B'; 'C'; 'D'; 'E'; 'F'; 'G'; 'H'; 'I'; 'J'; 'K'; 'L';
      'M'; 'N'; 'P'; 'Q'; 'R'; 'S'; 'T'; 'U'; 'W'; 'Y'; 'Z';
      '1'; '2'; '3'; '4'; '5'; '6'; '7'; '8'; '9';
    |]
  in
  let password_length = 10 in
  let password = String.create password_length in
    for i = 0 to (String.length password) - 1 do
      let c = symbol.(Random.State.int (rng ()) (Array.length symbol)) in
        String.set password i c
    done;
    password

let check_user t =
  let user_domainsdir = user_domainsdir t in
  if not (Sys.file_exists user_domainsdir) then
    failwith
      (Printf.sprintf "Sekred domain dir '%s' doesn't exist."
         user_domainsdir);
  if not (Sys.is_directory user_domainsdir) then
    failwith
      (Printf.sprintf "Sekred domains dir '%s' is not a directory."
         user_domainsdir);
  if (t.conf.stat user_domainsdir).Unix.st_uid <> t.uid then
    failwith
      (Printf.sprintf "Sekred domains dir '%s' doesn't belong to user %s."
         user_domainsdir (name_of_uid t.uid))

let get t domain =
  check_user t;
  if exists t domain then begin
    if has_access t domain then begin
      let chn = open_in (to_filename t domain) in
      let final () = close_in chn in
        try
          let password = input_line chn in
            final ();
            password
        with e ->
          final ();
          raise e
    end else begin
      failwith
        (Printf.sprintf
           "No access to domain '%s'."
           domain)
    end
  end else begin
    let password = pwgen () in
      set t domain password;
      password
  end

let list t =
  let () = check_user t in
  let lst =
    Array.fold_left
      (fun lst domain ->
         if exists t domain && has_access t domain then
           domain :: lst
         else
           lst)
      []
      (Sys.readdir (user_domainsdir t))
  in
    List.sort String.compare lst

let delete t domain =
  check_user t;
  if exists t domain && has_access t domain then
    Sys.remove (to_filename t domain)
  else
    failwith
      (Printf.sprintf
         "Unable to remove domain '%s'."
          domain)

let enable t =
  let user_domainsdir = user_domainsdir t in
    if not (Sys.file_exists user_domainsdir) then begin
      let st =
        Unix.mkdir user_domainsdir 0o750;
        t.conf.stat user_domainsdir
      in
        t.conf.chown user_domainsdir t.uid st.Unix.st_gid
    end

let disable t =
  let user_domainsdir = user_domainsdir t in
    Array.iter Sys.remove (ls_full user_domainsdir);
    Unix.rmdir user_domainsdir

let is_enabled t =
  try
    check_user t;
    true
  with Failure _ ->
    false

let create ?(conf=default_conf) ?(uid=Unix.getuid ()) enable =
  {conf = conf; uid = uid}

let upgrade_from_v0_1 conf =
  (* Transfer v0.1 domain files to v0.2 *)
  let upgrade_file fn =
    let uid = (conf.stat fn).Unix.st_uid in
    let domain = Filename.basename fn in
    let passwd =
      let chn_in = open_in fn in
      let passwd = input_line chn_in in
        close_in chn_in;
        passwd
    in
    let t = create ~conf ~uid () in
      enable t;
      set t domain passwd;
      Sys.remove fn
  in

  (* Fix domainsdir ACL. *)
  let domainsdir = domainsdir conf in
  let domains_stats = conf.stat domainsdir in
    if domains_stats.Unix.st_perm <> 0o751 then
      conf.chmod domainsdir 0o751;

    (* Fix files. *)
    Array.iter
      (fun fn ->
         if (conf.stat fn).Unix.st_kind = Unix.S_REG then
           upgrade_file fn)
      (ls_full domainsdir)

let init ?(conf=default_conf) () =
  let domainsdir = domainsdir conf in
  (* Create vardir, if needed. *)
  if not (Sys.file_exists conf.vardir) then
    Unix.mkdir conf.vardir 0o755;
  (* Create domainsdir, if needed. *)
  if not (Sys.file_exists domainsdir) then
    Unix.mkdir domainsdir 0o751;
  upgrade_from_v0_1 conf

let check ?(conf=default_conf) () =
  let spf fmt = Printf.sprintf fmt in
  let domainsdir = domainsdir conf in
    if not (Sys.file_exists domainsdir)
      || not (Sys.is_directory domainsdir) then begin
      [spf "Sekred domains dir '%s' doesn't exist." domainsdir]
    end else begin
      let lst = [] in
      let st = conf.stat domainsdir in
      let lst =
        if st.st_perm <> 0o751 then
          (spf "'%s' permission is %o but should be %o."
             domainsdir st.st_perm 0o751) :: lst
        else
          lst
      in
      let lst =
        if st.st_uid <> 0 then
          (spf "'%s' owner is '%d' but should be 'root'."
             domainsdir st.st_uid) :: lst
        else
          lst
      in
      let lst =
        if st.st_gid <> 0 then
          (spf "'%s' group is '%d' but should be 'root'."
             domainsdir st.st_gid) :: lst
        else
          lst
      in
      let rec check_files lst =
        function
          | fn :: tl ->
              let st = conf.stat fn in
              let lst =
                if st.st_kind <> Unix.S_REG then
                  (spf "'%s' should be a file." fn) :: lst
                else if st.st_perm <> 0o0600 then
                  (spf "'%s' file permission if %o but should be 0o0600."
                     fn st.st_perm) :: lst
                else
                  lst
              in
                check_files lst tl
          | [] ->
              lst
      in
        Array.fold_left
          (fun lst dn ->
             if Sys.is_directory dn then begin
               let st = conf.stat dn in
               let t' = {conf = conf; uid = st.Unix.st_uid} in
               if user_domainsdir t' <> dn then begin
                 (spf "'%s' user dir should be '%s'."
                    dn (user_domainsdir t'))
                 :: lst
               end else begin
                 let lst =
                   if st.Unix.st_perm <> 0o750 then
                     (spf "'%s' directory permision is %o but should be 0o750."
                        dn st.Unix.st_perm) :: lst
                   else
                     lst
                 in
                  check_files lst (Array.to_list (ls_full dn))
               end
             end else begin
               (spf "'%s' should be a directory." dn) :: lst
             end)
          lst (ls_full domainsdir)
    end
