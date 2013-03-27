type action_t = 
  | Get of string
  | Delete of string
  | Set of string * string
  | Check 
  | Init
  | List 
  | Help

let () = 
  let faction = 
    ref (fun () -> List)
  in
  let password = 
    ref (fun () ->
           failwith "You need to set --password=... for this action.")
  in
  let vardir =
    ref None
  in
  let args = 
    [
      "--vardir",
      Arg.String
        (fun fn -> vardir := Some fn),
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
  let vardir = !vardir in
  let action = !faction () in
  let t () = Sekred.create ?vardir () in (* TODO: uid *)
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
          let lst = Sekred.check (t ()) in
            if lst <> [] then
              begin
                List.iter prerr_endline lst;
                exit 1
              end
      | Init ->
          Sekred.init ?vardir ()
      | Help ->
          Arg.usage (Arg.align args) usage_msg; 
          exit 2



