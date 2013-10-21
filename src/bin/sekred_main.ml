open Sekred

type action_t =
  | Get of string
  | Delete of string
  | Set of string * string
  | Check
  | Init
  | List
  | Help

let () =
  let faction = ref (fun () -> List) in
  let password =
    ref (fun () ->
           failwith "You need to set --password=... for this action.")
  in
  let vardir = ref default_conf.vardir in
  let uid = ref None in
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
      "uid User id to create the password (N.B. only work as root)."
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
  sekred [options*] list
  sekred [options*] init

Options:\n" SekredConf.version
  in
  let () =
    Arg.parse
      (Arg.align args)
      (fun str -> lst := str :: !lst)
      usage_msg
  in
  let () =
    match List.rev !lst with
      | ["get"; domain] ->
          faction := (fun () -> Get domain)
      | ["delete"; domain] ->
          faction := (fun () -> Delete domain)
      | ["set"; domain] ->
          faction := (fun () -> Set (domain, !password ()))
      | ["list"] ->
          faction := (fun () -> List)
      | ["check"] ->
          faction := (fun () -> Check)
      | ["init"] ->
          faction := (fun () -> Init)
      | _ ->
          faction := (fun () -> Help)
  in
  let conf = {default_conf with vardir = !vardir} in
  let uid = !uid in
  let action = !faction () in
  let t () = Sekred.create ~conf ?uid () in
    match action with
      | Get domain ->
          print_endline (Sekred.get (t ()) domain)
      | Delete domain ->
          Sekred.delete (t ()) domain
      | Set (domain, password) ->
          Sekred.set (t ()) domain password
      | List ->
          List.iter print_endline (Sekred.list (t ()))
      | Check ->
          let lst = Sekred.check ~conf () in
            if lst <> [] then
              begin
                List.iter prerr_endline lst;
                exit 1
              end
      | Init ->
          Sekred.init ~conf ()
      | Help ->
          Arg.usage (Arg.align args) usage_msg;
          exit 2



