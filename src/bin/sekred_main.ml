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
