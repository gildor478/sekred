
open Unix

type t = 
    {
      vardir: string;
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

let to_filename t domain =
  Filename.concat t.vardir domain

let has_access t domain =
  try
    Unix.access (to_filename t domain) [Unix.R_OK];
    true
  with Unix.Unix_error _ ->
    false

let exists t domain =
  let fn = to_filename t domain in
    Sys.file_exists fn && not (Sys.is_directory fn)

let set t domain password =
  let fix_right () = 
    if exists t domain then
      begin
        let fn = to_filename t domain in
        let st = Unix.stat fn in
        Unix.chown fn t.uid st.Unix.st_gid;
        Unix.chmod fn 0o600
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

let get t domain =
  if exists t domain then
    begin
      if has_access t domain then
        begin
          let chn = open_in (to_filename t domain) in
          let final () = close_in chn in
            try 
              let password = input_line chn in
                final ();
                password
            with e ->
              final ();
              raise e
        end
      else
        failwith 
          (Printf.sprintf
             "No access to domain '%s'"
             domain)
    end
  else
    begin
      let password = pwgen () in
        set t domain password;
        password
    end

let list t =
  if not (Sys.file_exists t.vardir) || not (Sys.is_directory t.vardir) then
    failwith 
      (Printf.sprintf
         "Sekred vardir '%s' doesn't exist"
         t.vardir)
  else
    let lst =
      Array.fold_left
        (fun lst domain ->
           if exists t domain && has_access t domain then
             domain :: lst
           else
             lst)
        []
        (Sys.readdir t.vardir)
    in
      List.sort String.compare lst

let delete t domain =
  if exists t domain && has_access t domain then
    Sys.remove (to_filename t domain)
  else
    failwith 
      (Printf.sprintf
         "Unable to remove domain '%s'."
          domain)

let init ?(vardir=SekredConf.vardir) () =
  if not (Sys.file_exists vardir) then
    Unix.mkdir vardir 0o1730; (* Special mode, like crontabs directory. *)
  Unix.chmod vardir 0o1730

let check t =
  let spf fmt = Printf.sprintf fmt in
    if not (Sys.file_exists t.vardir) || not (Sys.is_directory t.vardir) then
      begin
        [spf "Sekred vardir '%s' doesn't exist." t.vardir]
      end
    else
      begin
        let lst = [] in
        let st = Unix.stat t.vardir in
        let lst =
          if st.st_perm != 0o1730 then
            (spf "'%s' permission is %o but should be %o."
               t.vardir st.st_perm 0o1730) :: lst
          else
            lst
        in
        let lst =
          if st.st_uid != 0 then
            (spf "'%s' owner is '%d' but should be 'root'."
               t.vardir st.st_uid) :: lst
          else
            lst
        in
        let lst = 
          if st.st_gid != 0 then
            (spf "'%s' group is '%d' but should be 'root'."
               t.vardir st.st_gid) :: lst
          else
            lst
        in
        let rec check_files lst =
          function
            | fn :: tl ->
                let full_fn = Filename.concat t.vardir fn in
                let st = Unix.stat full_fn in
                let lst = 
                  if st.st_kind != Unix.S_REG then
                    (spf "'%s' should be a file." full_fn) :: lst
                  else if st.st_perm != 0o0600 then
                    (spf "'%s' file permission if %o but should be 0o0600."
                       full_fn st.st_perm) :: lst
                  else
                    lst
                in
                  check_files lst tl
            | [] ->
                lst
        in
          check_files lst (Array.to_list (Sys.readdir t.vardir))
      end

let create ?(vardir=SekredConf.vardir) ?(uid=Unix.getuid ()) () =
  if not (Sys.file_exists vardir) || not (Sys.is_directory vardir) then
    failwith 
      (Printf.sprintf 
         "Sekred vardir '%s' doesn't exist."
         vardir);
  {
    vardir = vardir;
    uid    = uid;
  }
